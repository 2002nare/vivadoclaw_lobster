#!/usr/bin/env bash
# llm_refine.sh — Call llm-task to refine a spec based on critical review issues
#
# Usage: llm_refine.sh <prompt_file> <schema_file> <review_json_file> <spec_document_file>
# Environment:
#   OPENCLAW_URL   — OpenClaw gateway URL
#   OPENCLAW_TOKEN — Bearer token

set -euo pipefail

PROMPT_FILE="$1"
SCHEMA_FILE="$2"
REVIEW_JSON="$3"
SPEC_FILE="$4"

PROMPT=$(cat "$PROMPT_FILE")
SCHEMA=$(cat "$SCHEMA_FILE")
SPEC_DOC=$(cat "$SPEC_FILE")

# Extract only critical issues from the review JSON
CRITICAL_ISSUES=$(jq '{
  critical_issues: [.issues[] | select(.severity == "critical")],
  relevant_spec_fixes: [.spec_fixes[]],
  verdict: .verdict
}' "$REVIEW_JSON")

CRITICAL_COUNT=$(echo "$CRITICAL_ISSUES" | jq '.critical_issues | length')

if [ "$CRITICAL_COUNT" -eq 0 ]; then
  echo "No critical issues found — skipping refine step." >&2
  echo '{"refined_spec":"","changes":[],"summary":{"total_critical_issues":0,"applied":0,"deferred":0,"description":"No critical issues to fix."}}'
  exit 0
fi

echo "Found $CRITICAL_COUNT critical issue(s) to address." >&2

# Combine spec + critical issues as input
INPUT=$(jq -n \
  --arg spec "$SPEC_DOC" \
  --argjson criticals "$CRITICAL_ISSUES" \
  '{
    original_spec: $spec,
    review_criticals: $criticals
  }')

# Build request body
REQUEST_BODY=$(jq -n \
  --arg prompt "$PROMPT" \
  --arg input "$INPUT" \
  --argjson schema "$SCHEMA" \
  '{
    tool: "llm-task",
    action: "json",
    args: {
      prompt: $prompt,
      input: $input,
      schema: $schema,
      maxTokens: 16000,
      timeoutMs: 300000
    }
  }')

# Call OpenClaw API
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  --max-time 310 \
  -X POST "${OPENCLAW_URL}/tools/invoke" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENCLAW_TOKEN}" \
  -d "$REQUEST_BODY")

HTTP_STATUS=$(echo "$RESPONSE" | tail -1 | sed 's/HTTP_STATUS://')
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" -ge 400 ] 2>/dev/null; then
  echo "llm_refine.sh: HTTP $HTTP_STATUS" >&2
  echo "$BODY" >&2
  exit 1
fi

# Extract the JSON text from the response
echo "$BODY" | jq -r '.result.content[0].text // .result[0].content[0].text // empty'
