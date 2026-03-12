# impl_split.lobster — Vivado non-project implementation + split bitstream workflow
#
# Flow:
#   route/impl step -> save post-route checkpoint/reports
#   reopen checkpoint -> write bitstream
#   capture impl state -> AI review
#
# Notes:
# - Uses scripts/vivado_run.sh so LD_PRELOAD/libudev workaround is preserved.
# - Intended for board-targeted top modules with complete XDC constraints.

name: vivado-impl-split
description: "Run Vivado implementation through route_design, save checkpoint, reopen and write bitstream, then review results"

args:
  part:
    description: "FPGA part number (e.g., xc7a35tcpg236-1)"
  project_dir:
    description: "Absolute output directory for implementation artifacts"
  top_module:
    description: "Top module name for implementation/bitstream"
  sources_json:
    description: "JSON array of source file objects. All paths must be absolute. [{path, type, library}]"
  constraints_json:
    description: "JSON array of constraint file objects. All paths must be absolute. [{path}]"

env:
  VIVADO_PART: "${part}"
  VIVADO_PROJECT_DIR: "${project_dir}"
  VIVADO_TOP_MODULE: "${top_module}"
  VIVADO_SOURCES_JSON: "${sources_json}"
  VIVADO_CONSTRAINTS_JSON: "${constraints_json}"

steps:
  - id: check_env
    command: |
      export OPENCLAW_URL="${OPENCLAW_URL:-http://127.0.0.1:18789}"
      export OPENCLAW_TOKEN="${OPENCLAW_TOKEN:-$(cat ~/.openclaw/openclaw.json 2>/dev/null | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')}"
      if [ -z "$OPENCLAW_TOKEN" ]; then
        echo "ERROR: OPENCLAW_TOKEN is not set and could not be read from ~/.openclaw/openclaw.json" >&2
        exit 1
      fi

  - id: impl_route
    command: "bash scripts/vivado_run.sh scripts/vivado/run_impl_route_split.tcl"

  - id: write_bitstream
    command: "bash scripts/vivado_run.sh scripts/vivado/write_bitstream_from_checkpoint.tcl"

  - id: impl_state
    command: "bash scripts/vivado_run.sh scripts/vivado/get_impl_state.tcl"

  - id: review
    command: "bash scripts/llm_review.sh prompts/impl-review.md schemas/impl-review.schema.json"
    stdin: $impl_state.stdout
