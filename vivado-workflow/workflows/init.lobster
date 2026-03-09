# init.lobster — Vivado Project Initialization Workflow
#
# Flow: create → add sources → add constraints → set top → compile order
#       → state capture → AI review → auto-patch → re-review → final state
#
# Max 2 review cycles. Patches auto-applied (no approval gate).
# All data passed via environment variables (Vivado batch mode doesn't forward stdin).
#
# Required env vars (set before running):
#   OPENCLAW_URL   — OpenClaw gateway URL
#   OPENCLAW_TOKEN — Bearer token for OpenClaw API

name: vivado-init
description: "Initialize a Vivado FPGA project with AI-assisted review and auto-patching"

args:
  project_name:
    description: "Vivado project name"
  part:
    description: "FPGA part number (e.g., xc7a35tcpg236-1)"
  project_dir:
    description: "Directory to create/open the project in"
  top_module:
    description: "Top module name"
  sources_json:
    description: "JSON array of source file objects [{path, type, library}]"
  constraints_json:
    default: "[]"
    description: "JSON array of constraint file objects [{path}]"

env:
  VIVADO_PROJECT_NAME: "${project_name}"
  VIVADO_PART: "${part}"
  VIVADO_PROJECT_DIR: "${project_dir}"
  VIVADO_TOP_MODULE: "${top_module}"
  VIVADO_SOURCES_JSON: "${sources_json}"
  VIVADO_CONSTRAINTS_JSON: "${constraints_json}"

steps:
  # --- Phase 1: Create project ---
  - id: create_project
    command: "bash scripts/vivado_run.sh scripts/vivado/create_project.tcl"

  # --- Phase 1: Add RTL sources ---
  - id: add_sources
    command: "bash scripts/vivado_run.sh scripts/vivado/add_sources.tcl"

  # --- Phase 1: Add XDC constraints ---
  - id: add_constraints
    command: "bash scripts/vivado_run.sh scripts/vivado/add_constraints.tcl"

  # --- Phase 1: Set top module ---
  - id: set_top
    command: "bash scripts/vivado_run.sh scripts/vivado/set_top.tcl"

  # --- Phase 1: Update compile order ---
  - id: update_compile_order
    command: "bash scripts/vivado_run.sh scripts/vivado/update_compile_order.tcl"

  # --- Phase 2: Capture project state ---
  - id: state1
    command: "bash scripts/vivado_run.sh scripts/vivado/get_project_state.tcl"

  # --- Phase 3: AI review (cycle 1) ---
  # Uses curl to call OpenClaw llm-task API directly
  - id: review1
    command: "bash scripts/llm_review.sh prompts/init-review.md schemas/init-review.schema.json"
    stdin: $state1.stdout

  # --- Phase 4: Auto-apply patches ---
  # If status == "pass", patches array is empty → apply_patch is a no-op
  - id: apply_patches
    command: "bash scripts/vivado_run.sh scripts/vivado/apply_patch.tcl"
    env:
      VIVADO_PATCHES_JSON: $review1.stdout

  # --- Phase 5: Re-capture state after patching ---
  - id: state2
    command: "bash scripts/vivado_run.sh scripts/vivado/get_project_state.tcl"

  # --- Phase 5: AI review (cycle 2 — stricter) ---
  - id: review2
    command: "bash scripts/llm_review.sh prompts/init-review-cycle2.md schemas/init-review.schema.json"
    stdin: $state2.stdout

  # --- Phase 6: Final state capture ---
  - id: final_state
    command: "bash scripts/vivado_run.sh scripts/vivado/get_project_state.tcl"
