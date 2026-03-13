# review.lobster — Hardware Specification Review Tool
#
# Flow: receive spec document → AI review → output structured JSON review
#
# Single llm-task that reviews a hardware spec and returns structured findings.
#
# Required env vars (set before running):
#   OPENCLAW_URL   — OpenClaw gateway URL
#   OPENCLAW_TOKEN — Bearer token for OpenClaw API

name: spec-review
description: "Review a hardware specification document and return structured JSON feedback"

args:
  spec_document:
    description: "The hardware specification document text to review (full JSON or markdown content)"

steps:
  # --- Env check: ensure OpenClaw connection vars are set ---
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

  # --- AI Review: analyze spec and produce structured review ---
  - id: review
    command: "bash scripts/llm_review.sh prompts/spec-review.md schemas/spec-review.schema.json"
    stdin: "${spec_document}"
