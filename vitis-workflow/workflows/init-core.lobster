name: vitis-hls-init-core
description: "Initialize a Vitis HLS project without AI review"

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

  - id: final_state
    command: "bash scripts/vitis_hls_run.sh scripts/vitis_hls/get_project_state.tcl"
