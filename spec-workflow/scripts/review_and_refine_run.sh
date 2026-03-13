#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p output

echo "=== Run: ${TIMESTAMP} ===" >&2

SPEC_FILE="output/spec_input_${TIMESTAMP}.txt"
cat > "$SPEC_FILE"
echo "Saved input spec: $SPEC_FILE" >&2

echo "Running review..." >&2
REVIEW=$(bash scripts/llm_review.sh prompts/spec-review.md schemas/spec-review.schema.json < "$SPEC_FILE")
REVIEW_FILE="output/review_${TIMESTAMP}.json"
printf '%s\n' "$REVIEW" > "$REVIEW_FILE"
echo "Review saved: $REVIEW_FILE" >&2

CRITICAL=$(echo "$REVIEW" | jq '[.issues[] | select(.severity == "critical")] | length')
MAJOR=$(echo "$REVIEW" | jq '[.issues[] | select(.severity == "major")] | length')
MINOR=$(echo "$REVIEW" | jq '[.issues[] | select(.severity == "minor")] | length')
VERDICT=$(echo "$REVIEW" | jq -r '.verdict.status')
echo "Review: ${CRITICAL} critical, ${MAJOR} major, ${MINOR} minor — verdict: ${VERDICT}" >&2

if [ "$CRITICAL" -eq 0 ]; then
  echo "No critical issues — refine step skipped." >&2
  REFINE_RESULT='{"refined_spec":"","changes":[],"summary":{"total_critical_issues":0,"applied":0,"deferred":0,"description":"No critical issues to fix."}}'
else
  echo "Refining: ${CRITICAL} critical issue(s)..." >&2
  REFINE_RESULT=$(bash scripts/llm_refine.sh \
    prompts/spec-refine.md \
    schemas/spec-refine.schema.json \
    "$REVIEW_FILE" \
    "$SPEC_FILE")
fi

REFINE_FILE="output/refine_${TIMESTAMP}.json"
printf '%s\n' "$REFINE_RESULT" > "$REFINE_FILE"
echo "Refine saved: $REFINE_FILE" >&2

REFINED_SPEC=$(echo "$REFINE_RESULT" | jq -r '.refined_spec // empty')
if [ -n "$REFINED_SPEC" ]; then
  SPEC_OUT="output/spec_refined_${TIMESTAMP}.txt"
  printf '%s\n' "$REFINED_SPEC" > "$SPEC_OUT"
  echo "Refined spec saved: $SPEC_OUT" >&2
fi

CHANGELOG="output/changelog_${TIMESTAMP}.log"
{
  echo "=== Spec Review & Refine Changelog ==="
  echo "Run ID:    ${TIMESTAMP}"
  echo "Date:      $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo
  echo "--- Review Summary ---"
  echo "Verdict: ${VERDICT}"
  echo "Issues:  ${CRITICAL} critical, ${MAJOR} major, ${MINOR} minor"
  echo
  echo "--- Critical Issues ---"
  echo "$REVIEW" | jq -r '.issues[] | select(.severity == "critical") | "[\(.id)] \(.topic)\n  Problem:  \(.problem)\n  Fix:      \(.recommended_fix)\n"'
  echo
  echo "--- Refinement Summary ---"
  echo "$REFINE_RESULT" | jq -r '.summary | "Total critical: \(.total_critical_issues) | Applied: \(.applied) | Deferred: \(.deferred)\n\(.description)"'
  echo
  echo "--- Applied Changes ---"
  echo "$REFINE_RESULT" | jq -r '.changes[] | select(.status == "applied") | "[\(.issue_id)] \(.section)\n  Before: \(.original_text)\n  After:  \(.revised_text)\n  Why:    \(.rationale)\n"'
  DEFERRED_COUNT=$(echo "$REFINE_RESULT" | jq '[.changes[] | select(.status == "deferred")] | length')
  if [ "$DEFERRED_COUNT" -gt 0 ]; then
    echo "--- Deferred ---"
    echo "$REFINE_RESULT" | jq -r '.changes[] | select(.status == "deferred") | "[\(.issue_id)] \(.section)\n  Reason: \(.rationale)\n"'
  fi
} > "$CHANGELOG"
echo "Changelog saved: $CHANGELOG" >&2

echo
echo "========================================="
echo "  Review & Refine Complete"
echo "  Run: ${TIMESTAMP}"
echo "========================================="
echo
echo "Output files:"
ls -1 output/*_${TIMESTAMP}.* 2>/dev/null | while read -r f; do echo "  $f"; done
echo
echo "Review verdict: ${VERDICT}"
echo "Issues: ${CRITICAL} critical, ${MAJOR} major, ${MINOR} minor"
if [ "$CRITICAL" -gt 0 ]; then
  echo "Refine: $(echo "$REFINE_RESULT" | jq -r '.summary.description')"
fi
