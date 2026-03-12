# review_and_refine.lobster — Hardware Spec Review + Critical-Fix Refinement
#
# Flow:
#   1. receive spec document → save with timestamp
#   2. AI review → structured JSON review (timestamped)
#   3. AI refine → apply critical fixes only (timestamped)
#   4. save refined spec + human-readable changelog (all timestamped)
#
# Required env vars:
#   OPENCLAW_URL   — OpenClaw gateway URL
#   OPENCLAW_TOKEN — Bearer token for OpenClaw API
#
# Output files (in output/ directory):
#   spec_input_<timestamp>.txt      — original spec input
#   review_<timestamp>.json         — full review result
#   refine_<timestamp>.json         — refine result (changes + refined spec)
#   spec_refined_<timestamp>.txt    — refined spec document only
#   changelog_<timestamp>.log       — human-readable change log

name: spec-review-and-refine
description: "Review a hardware spec, then auto-fix critical issues with timestamped outputs"

args:
  spec_document:
    description: "The hardware specification document text to review (full JSON or markdown content)"

steps:
  # --- Env check ---
  - id: check_env
    command: |
      export OPENCLAW_URL="${OPENCLAW_URL:-http://127.0.0.1:18789}"
      export OPENCLAW_TOKEN="${OPENCLAW_TOKEN:-$(cat ~/.openclaw/openclaw.json 2>/dev/null | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')}"
      if [ -z "$OPENCLAW_TOKEN" ]; then
        echo "ERROR: OPENCLAW_TOKEN is not set and could not be read from ~/.openclaw/openclaw.json" >&2
        exit 1
      fi
      echo "OPENCLAW_URL=$OPENCLAW_URL"
      echo "OPENCLAW_TOKEN is set (${#OPENCLAW_TOKEN} chars)"

  # --- Review + Refine pipeline (single step for reliable data flow) ---
  - id: review_and_refine
    command: |
      set -euo pipefail

      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      mkdir -p output

      echo "=== Run: ${TIMESTAMP} ===" >&2

      # 1. Save input spec
      SPEC_FILE="output/spec_input_${TIMESTAMP}.txt"
      cat > "$SPEC_FILE"
      echo "Saved input spec: $SPEC_FILE" >&2

      # 2. Review
      echo "Running review..." >&2
      REVIEW=$(bash scripts/llm_review.sh prompts/spec-review.md schemas/spec-review.schema.json < "$SPEC_FILE")
      REVIEW_FILE="output/review_${TIMESTAMP}.json"
      echo "$REVIEW" > "$REVIEW_FILE"
      echo "Review saved: $REVIEW_FILE" >&2

      # Show review summary
      CRITICAL=$(echo "$REVIEW" | jq '[.issues[] | select(.severity == "critical")] | length')
      MAJOR=$(echo "$REVIEW" | jq '[.issues[] | select(.severity == "major")] | length')
      MINOR=$(echo "$REVIEW" | jq '[.issues[] | select(.severity == "minor")] | length')
      VERDICT=$(echo "$REVIEW" | jq -r '.verdict.status')
      echo "Review: ${CRITICAL} critical, ${MAJOR} major, ${MINOR} minor — verdict: ${VERDICT}" >&2

      # 3. Refine (critical only)
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

      # Save refine result
      REFINE_FILE="output/refine_${TIMESTAMP}.json"
      echo "$REFINE_RESULT" > "$REFINE_FILE"
      echo "Refine saved: $REFINE_FILE" >&2

      # Extract and save refined spec (if non-empty)
      REFINED_SPEC=$(echo "$REFINE_RESULT" | jq -r '.refined_spec // empty')
      if [ -n "$REFINED_SPEC" ]; then
        SPEC_OUT="output/spec_refined_${TIMESTAMP}.txt"
        echo "$REFINED_SPEC" > "$SPEC_OUT"
        echo "Refined spec saved: $SPEC_OUT" >&2
      fi

      # 4. Generate changelog
      CHANGELOG="output/changelog_${TIMESTAMP}.log"
      {
        echo "=== Spec Review & Refine Changelog ==="
        echo "Run ID:    ${TIMESTAMP}"
        echo "Date:      $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo ""
        echo "--- Review Summary ---"
        echo "Verdict: ${VERDICT}"
        echo "Issues:  ${CRITICAL} critical, ${MAJOR} major, ${MINOR} minor"
        echo ""
        echo "--- Critical Issues ---"
        echo "$REVIEW" | jq -r '.issues[] | select(.severity == "critical") | "[\(.id)] \(.topic)\n  Problem:  \(.problem)\n  Fix:      \(.recommended_fix)\n"'
        echo ""
        echo "--- Refinement Summary ---"
        echo "$REFINE_RESULT" | jq -r '.summary | "Total critical: \(.total_critical_issues) | Applied: \(.applied) | Deferred: \(.deferred)\n\(.description)"'
        echo ""
        echo "--- Applied Changes ---"
        echo "$REFINE_RESULT" | jq -r '.changes[] | select(.status == "applied") | "[\(.issue_id)] \(.section)\n  Before: \(.original_text)\n  After:  \(.revised_text)\n  Why:    \(.rationale)\n"'
        DEFERRED_COUNT=$(echo "$REFINE_RESULT" | jq '[.changes[] | select(.status == "deferred")] | length')
        if [ "$DEFERRED_COUNT" -gt 0 ]; then
          echo "--- Deferred ---"
          echo "$REFINE_RESULT" | jq -r '.changes[] | select(.status == "deferred") | "[\(.issue_id)] \(.section)\n  Reason: \(.rationale)\n"'
        fi
      } > "$CHANGELOG"
      echo "Changelog saved: $CHANGELOG" >&2

      # 5. Final output
      echo ""
      echo "========================================="
      echo "  Review & Refine Complete"
      echo "  Run: ${TIMESTAMP}"
      echo "========================================="
      echo ""
      echo "Output files:"
      ls -1 output/*_${TIMESTAMP}.* 2>/dev/null | while read f; do echo "  $f"; done
      echo ""
      echo "Review verdict: ${VERDICT}"
      echo "Issues: ${CRITICAL} critical, ${MAJOR} major, ${MINOR} minor"
      if [ "$CRITICAL" -gt 0 ]; then
        echo "Refine: $(echo "$REFINE_RESULT" | jq -r '.summary.description')"
      fi
    stdin: "${spec_document}"
