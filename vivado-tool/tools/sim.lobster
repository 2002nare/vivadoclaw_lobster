# sim.lobster — Vivado Behavioral Simulation Workflow
#
# Flow: add sim sources → capture state → preflight check (abort if misconfigured)
#       → run simulation → capture state → AI review (report only)
#
# No auto-patching. Review results are returned for the user to act on.
# Assumes project is already initialized (init.lobster completed).
#
# Required env vars (set before running):
#   OPENCLAW_URL   — OpenClaw gateway URL
#   OPENCLAW_TOKEN — Bearer token for OpenClaw API

name: vivado-sim
description: "Run Vivado behavioral simulation with AI-assisted review"

args:
  project_dir:
    description: "Absolute path to Vivado project directory (must contain .xpr file)"
  sim_sources_json:
    description: "JSON array of simulation source files. All paths must be absolute. [{path, type}]"
  sim_top:
    default: ""
    description: "Simulation top module (e.g., top_tb). Leave empty to use fileset default"
  sim_time:
    default: "1us"
    description: "Simulation run time (e.g., 100ns, 1us, 10us)"
  sim_fileset:
    default: "sim_1"
    description: "Simulation fileset name"

env:
  VIVADO_PROJECT_DIR: "${project_dir}"
  VIVADO_SIM_SOURCES_JSON: "${sim_sources_json}"
  VIVADO_SIM_TOP: "${sim_top}"
  VIVADO_SIM_TIME: "${sim_time}"
  VIVADO_SIM_FILESET: "${sim_fileset}"

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

  # --- Phase 1: Add sim sources to fileset ---
  - id: add_sim_sources
    command: "bash scripts/vivado_run.sh scripts/vivado/add_sim_sources.tcl"

  # --- Phase 2: Capture sim fileset state ---
  - id: pre_state
    command: "bash scripts/vivado_run.sh scripts/vivado/get_sim_state.tcl"

  # --- Phase 3: AI preflight check — abort if not ready ---
  - id: preflight
    command: "bash scripts/llm_review.sh prompts/sim-preflight.md schemas/sim-preflight.schema.json | bash scripts/check_preflight.sh"
    stdin: $pre_state.stdout

  # --- Phase 4: Run behavioral simulation ---
  - id: run_sim
    command: "bash scripts/vivado_run.sh scripts/vivado/run_simulation.tcl"

  # --- Phase 5: Capture simulation state (with logs) ---
  - id: state1
    command: "bash scripts/vivado_run.sh scripts/vivado/get_sim_state.tcl"

  # --- Phase 6: AI review (report only, no patches applied) ---
  - id: review
    command: "bash scripts/llm_review.sh prompts/sim-review.md schemas/sim-review.schema.json"
    stdin: $state1.stdout
