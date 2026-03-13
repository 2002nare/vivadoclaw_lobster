name: vitis-hls-sim
description: "Run Vitis HLS C simulation (csim_design)"

args:
  project_name:
    description: "HLS project name"
  part:
    description: "FPGA part number"
  project_dir:
    description: "Absolute path to parent directory"
  top_function:
    description: "Top-level function name"
  sources_json:
    description: "JSON array of source file objects"
  testbench_json:
    default: "[]"
    description: "JSON array of testbench file objects"
  solution_name:
    default: "solution1"
  clock_period:
    default: "10"

env:
  VITIS_HLS_PROJECT_NAME: "${project_name}"
  VITIS_HLS_PART: "${part}"
  VITIS_HLS_PROJECT_DIR: "${project_dir}"
  VITIS_HLS_TOP_FUNCTION: "${top_function}"
  VITIS_HLS_SOURCES_JSON: "${sources_json}"
  VITIS_HLS_TESTBENCH_JSON: "${testbench_json}"
  VITIS_HLS_SOLUTION_NAME: "${solution_name}"
  VITIS_HLS_CLOCK_PERIOD: "${clock_period}"

steps:
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

  - id: run_csim
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/run_csim.tcl"

  - id: final_state
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/get_sim_state.tcl"

  - id: review
    command: "bash scripts/llm_review.sh prompts/sim-review.md schemas/sim-review.schema.json"
    stdin: $final_state.stdout
