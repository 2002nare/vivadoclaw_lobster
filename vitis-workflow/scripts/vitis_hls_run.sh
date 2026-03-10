#!/usr/bin/env bash
# vitis_hls_run.sh — thin Vitis HLS batch wrapper
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo '{"ok": false, "error": "Usage: vitis_hls_run.sh <tcl_script> [extra vitis_hls args...]"}'
  exit 1
fi

SCRIPT_ARG="$1"
shift || true

if [[ ! -f "$SCRIPT_ARG" ]]; then
  echo "{\"ok\": false, \"error\": \"Script not found: $SCRIPT_ARG\"}"
  exit 1
fi

SCRIPT="$(cd "$(dirname "$SCRIPT_ARG")" && pwd)/$(basename "$SCRIPT_ARG")"
: "${VITIS_HLS_PROJECT_DIR:?VITIS_HLS_PROJECT_DIR is required}"

RUN_DIR="${VITIS_HLS_RUN_DIR:-${VITIS_HLS_PROJECT_DIR}/run}"
mkdir -p "$RUN_DIR"
LOGFILE="$RUN_DIR/vitis_hls_run.log"
STEP_NAME="$(basename "$SCRIPT_ARG" .tcl)"
STEP_LOG="$RUN_DIR/${STEP_NAME}_$(date '+%Y%m%d_%H%M%S').log"
RESULT_JSON="$RUN_DIR/${STEP_NAME}.result.json"

log() {
  local msg="[$(date '+%H:%M:%S')] [vitis_hls_run] $*"
  echo "$msg" >> "$LOGFILE"
  echo "$msg" >&2
}

log "--- START: $SCRIPT_ARG ---"
log "Resolved script: $SCRIPT"
log "Run directory: $RUN_DIR"
log "VITIS_HLS_PROJECT_DIR=${VITIS_HLS_PROJECT_DIR:-<unset>}"
log "VITIS_HLS_PROJECT_NAME=${VITIS_HLS_PROJECT_NAME:-<unset>}"
log "VITIS_HLS_PART=${VITIS_HLS_PART:-<unset>}"
log "VITIS_HLS_TOP_FUNCTION=${VITIS_HLS_TOP_FUNCTION:-<unset>}"
log "VITIS_HLS_SOURCES_JSON=${VITIS_HLS_SOURCES_JSON:-<unset>}"
log "VITIS_HLS_TESTBENCH_JSON=${VITIS_HLS_TESTBENCH_JSON:-<unset>}"
log "VITIS_HLS_SOLUTION_NAME=${VITIS_HLS_SOLUTION_NAME:-<unset>}"
log "VITIS_HLS_CLOCK_PERIOD=${VITIS_HLS_CLOCK_PERIOD:-<unset>}"
log "VITIS_HLS_PATCHES_JSON=${VITIS_HLS_PATCHES_JSON:-<unset>}"

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export VITIS_HLS_RUN_DIR="$RUN_DIR"
export VITIS_HLS_RESULT_JSON="$RESULT_JSON"

rm -f "$RESULT_JSON"

if ! command -v vitis_hls &>/dev/null; then
  echo '{"ok": false, "error": "vitis_hls not found in PATH; activate the Vitis HLS environment first"}'
  exit 1
fi

cd "$RUN_DIR"

HLS_EXIT=0
if command -v timeout >/dev/null 2>&1; then
  timeout --signal=TERM 300 vitis_hls -f "$SCRIPT" "$@" >"$STEP_LOG" 2>&1 || HLS_EXIT=$?
else
  vitis_hls -f "$SCRIPT" "$@" >"$STEP_LOG" 2>&1 || HLS_EXIT=$?
fi

log "Vitis HLS exit code: $HLS_EXIT"
log "Step log: $STEP_LOG"
log "--- Vitis HLS output (last 20 lines) ---"
tail -20 "$STEP_LOG" >> "$LOGFILE" || true
tail -20 "$STEP_LOG" >&2 || true

if [[ ! -f "$RESULT_JSON" ]]; then
  log "ERROR: Result JSON not produced"
  echo "{\"ok\": false, \"error\": \"Result JSON not produced\", \"step\": \"$STEP_NAME\", \"log\": \"$STEP_LOG\", \"exit\": $HLS_EXIT}"
  exit 1
fi

log "Result JSON: $RESULT_JSON"
log "--- END: $SCRIPT_ARG (exit=$HLS_EXIT) ---"
echo >> "$LOGFILE"
cat "$RESULT_JSON"
