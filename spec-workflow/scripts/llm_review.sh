#!/usr/bin/env bash
# llm_review.sh — Call llm-task via OpenClaw API (curl)
#
# Usage: echo "<spec_document>" | llm_review.sh <prompt_file> <schema_file>
# Environment:
#   OPENCLAW_URL   — OpenClaw gateway URL
#   OPENCLAW_TOKEN — Bearer token

set -euo pipefail

PROMPT_FILE="$1"
SCHEMA_FILE="$2"

# Read spec document from stdin, prompt/schema from files
SPEC_DOC=$(cat)
PROMPT=$(cat "$PROMPT_FILE")
SCHEMA=$(cat "$SCHEMA_FILE")

# Build request body with jq
REQUEST_BODY=$(jq -n \
  --arg prompt "$PROMPT" \
  --arg input "$SPEC_DOC" \
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

# Call OpenClaw API directly
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  --max-time 310 \
  -X POST "${OPENCLAW_URL}/tools/invoke" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENCLAW_TOKEN}" \
  -d "$REQUEST_BODY")

HTTP_STATUS=$(echo "$RESPONSE" | tail -1 | sed 's/HTTP_STATUS://')
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" -ge 400 ] 2>/dev/null; then
  echo "llm_review.sh: HTTP $HTTP_STATUS" >&2
  echo "$BODY" >&2
  exit 1
fi

# Extract the JSON text from the response
# Response format: {"ok":true,"result":{"content":[{"type":"text","text":"..."}],...}}
echo "$BODY" | jq -r '.result.content[0].text // .result[0].content[0].text // empty'
