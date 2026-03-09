#!/usr/bin/env bash
# check_preflight.sh — Parse preflight LLM result and abort if decision is "abort"
#
# Usage: echo "<preflight_json>" | check_preflight.sh
# Exit 0 if "proceed", exit 1 if "abort"
# stdout: the original JSON (passed through)

set -euo pipefail

INPUT=$(cat)

DECISION=$(echo "$INPUT" | jq -r '.decision // "abort"')

if [ "$DECISION" = "abort" ]; then
  REASON=$(echo "$INPUT" | jq -r '.reason // "Unknown reason"')
  echo "PREFLIGHT ABORT: $REASON" >&2
  echo "$INPUT" | jq -r '.issues[]? | "  [\(.severity)] \(.message)"' >&2
  echo "$INPUT"
  exit 1
fi

echo "$INPUT"
