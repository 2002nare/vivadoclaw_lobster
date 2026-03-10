#!/usr/bin/env bash
# vitis_hls_run.sh — Vitis HLS batch mode wrapper
# Handles: locale, run directory isolation, JSON output filtering
#
# Usage: vitis_hls_run.sh <tcl_script> [extra vitis_hls args...]
# Environment:
#   VITIS_HLS_PROJECT_DIR — project parent directory (required for run dir default)
#   VITIS_HLS_RUN_DIR     — override run directory (optional)
#   VITIS_HLS_DEBUG       — set to "1" for verbose debug logging
#
# stdout: single JSON line from Tcl script
# stderr + logfile: debug output

set -euo pipefail

# --- Logging ---
LOG_DIR="${VITIS_HLS_RUN_DIR:-${VITIS_HLS_PROJECT_DIR:-.}/run}"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/vitis_hls_run.log"

log() {
  local msg="[$(date '+%H:%M:%S')] [vitis_hls_run] $*"
  echo "$msg" >> "$LOGFILE"
  echo "$msg" >&2
}

if [[ $# -lt 1 ]]; then
  log "ERROR: No tcl script argument provided"
  echo '{"ok": false, "error": "Usage: vitis_hls_run.sh <tcl_script> [vitis_hls args...]"}'
  exit 1
fi

SCRIPT_ARG="$1"
log "--- START: $SCRIPT_ARG ---"
log "CWD: $(pwd)"

# Validate VITIS_HLS_PROJECT_DIR is absolute
if [[ -n "${VITIS_HLS_PROJECT_DIR:-}" && "${VITIS_HLS_PROJECT_DIR}" != /* ]]; then
  log "ERROR: VITIS_HLS_PROJECT_DIR must be an absolute path: $VITIS_HLS_PROJECT_DIR"
  echo '{"ok": false, "error": "VITIS_HLS_PROJECT_DIR must be an absolute path"}'
  exit 1
fi

log "VITIS_HLS_PROJECT_DIR=${VITIS_HLS_PROJECT_DIR:-<unset>}"
log "VITIS_HLS_PROJECT_NAME=${VITIS_HLS_PROJECT_NAME:-<unset>}"
log "VITIS_HLS_PART=${VITIS_HLS_PART:-<unset>}"
log "VITIS_HLS_TOP_FUNCTION=${VITIS_HLS_TOP_FUNCTION:-<unset>}"
log "VITIS_HLS_SOURCES_JSON=${VITIS_HLS_SOURCES_JSON:-<unset>}"
log "VITIS_HLS_TESTBENCH_JSON=${VITIS_HLS_TESTBENCH_JSON:-<unset>}"
log "VITIS_HLS_SOLUTION_NAME=${VITIS_HLS_SOLUTION_NAME:-<unset>}"
log "VITIS_HLS_CLOCK_PERIOD=${VITIS_HLS_CLOCK_PERIOD:-<unset>}"
log "VITIS_HLS_PATCHES_JSON=${VITIS_HLS_PATCHES_JSON:-<unset>}"

# Resolve script to absolute path
if [[ ! -f "$SCRIPT_ARG" ]]; then
  log "ERROR: Script file not found: $SCRIPT_ARG (from CWD=$(pwd))"
  echo "{\"ok\": false, \"error\": \"Script not found: $SCRIPT_ARG\"}"
  exit 1
fi
SCRIPT="$(cd "$(dirname "$SCRIPT_ARG")" && pwd)/$(basename "$SCRIPT_ARG")"
shift
log "Resolved script: $SCRIPT"

# UTF-8 locale preflight
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# --- Run directory isolation ---
RUN_DIR="${VITIS_HLS_RUN_DIR:-${VITIS_HLS_PROJECT_DIR:-.}/run}"
mkdir -p "$RUN_DIR"
log "Run directory: $RUN_DIR"
cd "$RUN_DIR"

# --- Check Vitis HLS is available ---
if ! command -v vitis_hls &>/dev/null; then
  log "ERROR: vitis_hls command not found in PATH"
  log "PATH=$PATH"
  echo '{"ok": false, "error": "vitis_hls not found in PATH"}'
  exit 1
fi
log "Vitis HLS found: $(which vitis_hls)"

# --- Execute Vitis HLS in batch mode ---
log "Executing: vitis_hls -f $SCRIPT $*"
HLS_EXIT=0
HLS_OUTPUT=$(vitis_hls -f "$SCRIPT" "$@" 2>&1) || HLS_EXIT=$?

log "Vitis HLS exit code: $HLS_EXIT"

# Save full output to separate log
STEP_LOG="$RUN_DIR/$(basename "$SCRIPT_ARG" .tcl)_$(date '+%Y%m%d_%H%M%S').log"
echo "$HLS_OUTPUT" > "$STEP_LOG"
log "Full Vitis HLS output saved to: $STEP_LOG"

# Show last 20 lines of output in debug log
log "--- Vitis HLS output (last 20 lines) ---"
echo "$HLS_OUTPUT" | tail -20 >> "$LOGFILE"
echo "$HLS_OUTPUT" | tail -20 >&2

# Extract the last JSON line
JSON_LINE=$(echo "$HLS_OUTPUT" | grep '^{' | tail -1 || true)

if [[ -z "$JSON_LINE" ]]; then
  log "ERROR: No JSON output found in Vitis HLS output"
  # Show first/last lines for context
  log "--- First 5 lines ---"
  echo "$HLS_OUTPUT" | head -5 >> "$LOGFILE"
  log "--- Last 5 lines ---"
  echo "$HLS_OUTPUT" | tail -5 >> "$LOGFILE"
  echo "{\"ok\": false, \"error\": \"No JSON output from $SCRIPT_ARG (exit=$HLS_EXIT)\"}"
  exit 1
fi

log "JSON output: $JSON_LINE"
log "--- END: $SCRIPT_ARG (exit=$HLS_EXIT) ---"
echo ""  >> "$LOGFILE"

echo "$JSON_LINE"
