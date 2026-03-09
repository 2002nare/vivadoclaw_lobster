#!/usr/bin/env bash
# vivado_run.sh — Vivado batch mode wrapper
# Handles: LD_PRELOAD workaround, locale, run directory isolation, JSON output filtering
#
# Usage: vivado_run.sh <tcl_script> [extra vivado args...]
# Environment:
#   VIVADO_PROJECT_DIR  — project directory (required for run dir default)
#   VIVADO_RUN_DIR      — override run directory (optional)
#   VIVADO_DEBUG        — set to "1" for verbose debug logging
#
# stdout: single JSON line from Tcl script
# stderr + logfile: debug output

set -euo pipefail

# --- Logging ---
LOG_DIR="${VIVADO_RUN_DIR:-${VIVADO_PROJECT_DIR:-.}/run}"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/vivado_run.log"

log() {
  local msg="[$(date '+%H:%M:%S')] [vivado_run] $*"
  echo "$msg" >> "$LOGFILE"
  echo "$msg" >&2
}

if [[ $# -lt 1 ]]; then
  log "ERROR: No tcl script argument provided"
  echo '{"ok": false, "error": "Usage: vivado_run.sh <tcl_script> [vivado args...]"}'
  exit 1
fi

SCRIPT_ARG="$1"
log "--- START: $SCRIPT_ARG ---"
log "CWD: $(pwd)"
log "VIVADO_PROJECT_DIR=${VIVADO_PROJECT_DIR:-<unset>}"
log "VIVADO_PROJECT_NAME=${VIVADO_PROJECT_NAME:-<unset>}"
log "VIVADO_PART=${VIVADO_PART:-<unset>}"
log "VIVADO_TOP_MODULE=${VIVADO_TOP_MODULE:-<unset>}"
log "VIVADO_SOURCES_JSON=${VIVADO_SOURCES_JSON:-<unset>}"
log "VIVADO_CONSTRAINTS_JSON=${VIVADO_CONSTRAINTS_JSON:-<unset>}"
log "VIVADO_PATCHES_JSON=${VIVADO_PATCHES_JSON:-<unset>}"

# Resolve script to absolute path
if [[ ! -f "$SCRIPT_ARG" ]]; then
  log "ERROR: Script file not found: $SCRIPT_ARG (from CWD=$(pwd))"
  echo "{\"ok\": false, \"error\": \"Script not found: $SCRIPT_ARG\"}"
  exit 1
fi
SCRIPT="$(cd "$(dirname "$SCRIPT_ARG")" && pwd)/$(basename "$SCRIPT_ARG")"
shift
log "Resolved script: $SCRIPT"

# --- Container workaround ---
if [[ -f /lib/x86_64-linux-gnu/libudev.so.1 ]]; then
  export LD_PRELOAD="${LD_PRELOAD:+$LD_PRELOAD:}/lib/x86_64-linux-gnu/libudev.so.1"
  log "LD_PRELOAD set: $LD_PRELOAD"
fi

# UTF-8 locale preflight
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# --- Run directory isolation ---
RUN_DIR="${VIVADO_RUN_DIR:-${VIVADO_PROJECT_DIR:-.}/run}"
mkdir -p "$RUN_DIR"
log "Run directory: $RUN_DIR"
cd "$RUN_DIR"

# --- Check Vivado is available ---
if ! command -v vivado &>/dev/null; then
  log "ERROR: vivado command not found in PATH"
  log "PATH=$PATH"
  echo '{"ok": false, "error": "vivado not found in PATH"}'
  exit 1
fi
log "Vivado found: $(which vivado)"

# --- Execute Vivado in batch mode ---
log "Executing: vivado -mode batch -source $SCRIPT $*"
VIVADO_EXIT=0
VIVADO_OUTPUT=$(vivado -mode batch -source "$SCRIPT" -nojournal -nolog "$@" 2>&1) || VIVADO_EXIT=$?

log "Vivado exit code: $VIVADO_EXIT"

# Save full output to separate log
STEP_LOG="$RUN_DIR/$(basename "$SCRIPT_ARG" .tcl)_$(date '+%Y%m%d_%H%M%S').log"
echo "$VIVADO_OUTPUT" > "$STEP_LOG"
log "Full Vivado output saved to: $STEP_LOG"

# Show last 20 lines of output in debug log
log "--- Vivado output (last 20 lines) ---"
echo "$VIVADO_OUTPUT" | tail -20 >> "$LOGFILE"
echo "$VIVADO_OUTPUT" | tail -20 >&2

# Extract the last JSON line
JSON_LINE=$(echo "$VIVADO_OUTPUT" | grep '^{' | tail -1 || true)

if [[ -z "$JSON_LINE" ]]; then
  log "ERROR: No JSON output found in Vivado output"
  # Show first/last lines for context
  log "--- First 5 lines ---"
  echo "$VIVADO_OUTPUT" | head -5 >> "$LOGFILE"
  log "--- Last 5 lines ---"
  echo "$VIVADO_OUTPUT" | tail -5 >> "$LOGFILE"
  echo "{\"ok\": false, \"error\": \"No JSON output from $SCRIPT_ARG (exit=$VIVADO_EXIT)\"}"
  exit 1
fi

log "JSON output: $JSON_LINE"
log "--- END: $SCRIPT_ARG (exit=$VIVADO_EXIT) ---"
echo ""  >> "$LOGFILE"

echo "$JSON_LINE"
