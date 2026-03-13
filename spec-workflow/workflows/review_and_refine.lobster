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
    command: "bash scripts/review_and_refine_run.sh"
    stdin: "${spec_document}"
