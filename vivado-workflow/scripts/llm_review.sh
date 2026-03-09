#!/usr/bin/env bash
# llm_review.sh — Call llm-task via openclaw.invoke.js
#
# Usage: echo "<project_state_json>" | llm_review.sh <prompt_file> <schema_file>
# Environment:
#   OPENCLAW_URL   — OpenClaw gateway URL
#   OPENCLAW_TOKEN — Bearer token

set -euo pipefail

PROMPT_FILE="$1"
SCHEMA_FILE="$2"

# Read project state from stdin, prompt/schema from files
PROJECT_STATE=$(cat)
PROMPT=$(cat "$PROMPT_FILE")
SCHEMA=$(cat "$SCHEMA_FILE")

# Build args JSON with jq
ARGS_JSON=$(jq -n \
  --arg prompt "$PROMPT" \
  --arg input "$PROJECT_STATE" \
  --argjson schema "$SCHEMA" \
  '{
    prompt: $prompt,
    input: $input,
    schema: $schema,
    maxTokens: 2000
  }')

# Call via openclaw.invoke.js
node /home/appuser/lobster/bin/openclaw.invoke.js \
  --tool llm-task \
  --action json \
  --args-json "$ARGS_JSON"

