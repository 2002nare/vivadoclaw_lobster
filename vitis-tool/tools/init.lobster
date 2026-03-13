# init.lobster — Vitis HLS Project Initialization Workflow with AI review
#
# Recommended default:
#   Use workflows/init-core.lobster first for stable project initialization.
#
# This workflow layers AI review and auto-patching on top of the core init path.
# It is more powerful, but also more dependent on OpenClaw connectivity,
# review prompts, schemas, and patch-application behavior.
#
# Flow:
#   core init → state capture → AI review → auto-patch → re-review → final state
#
# Required env vars (set before running this review workflow):
#   OPENCLAW_URL   — OpenClaw gateway URL
#   OPENCLAW_TOKEN — Bearer token for OpenClaw API

name: vitis-hls-init
description: "Initialize a Vitis HLS project with AI-assisted review and auto-patching"

args:
  project_name:
    description: "HLS project name"
  part:
    description: "FPGA part number (e.g., xc7a35tcpg236-1)"
  project_dir:
    description: "Absolute path to parent directory for HLS project"
  top_function:
    description: "Top-level C/C++ function name for synthesis"
  sources_json:
    description: "JSON array of source file objects. All paths must be absolute. [{path}]"
  testbench_json:
    default: "[]"
    description: "JSON array of testbench file objects. All paths must be absolute. [{path}]"
  solution_name:
    default: "solution1"
    description: "Solution name"
  clock_period:
    default: "10"
    description: "Clock period in nanoseconds (e.g., 10 = 100MHz)"

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

  # --- Phase 1: Stable core init ---
  - id: create_project
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/create_project.tcl"

  - id: add_sources
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/add_sources.tcl"

  - id: add_testbench
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/add_testbench.tcl"

  - id: create_solution
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/create_solution.tcl"

  - id: set_top
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/set_top.tcl"

  # --- Phase 2: State capture ---
  - id: state1
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/get_project_state.tcl"

  # --- Phase 3: AI review (cycle 1) ---
  - id: review1
    command: "bash scripts/llm_review.sh prompts/init-review.md schemas/init-review.schema.json"
    stdin: $state1.stdout

  # --- Phase 4: Auto-apply patches ---
  - id: apply_patches
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/apply_patch.tcl"
    env:
      VITIS_HLS_PATCHES_JSON: $review1.stdout

  # --- Phase 5: Re-capture state after patching ---
  - id: state2
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/get_project_state.tcl"

  # --- Phase 5: AI review (cycle 2 — stricter) ---
  - id: review2
    command: "bash scripts/llm_review.sh prompts/init-review-cycle2.md schemas/init-review.schema.json"
    stdin: $state2.stdout

  # --- Phase 6: Final state capture ---
  - id: final_state
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/get_project_state.tcl"
