# Vitis HLS Sim Workflow

## Overview

Run Vitis HLS C simulation (`csim_design`) using the same result-file handoff pattern established for `init-core.lobster`.

This is the recommended next step after project initialization: first use `workflows/init-core.lobster` or `workflows/init.lobster`, then run `workflows/sim.lobster` to validate the C testbench path before moving on to synthesis.

Current design keeps the flow simple:

```text
run_csim → get_sim_state → AI review
```

This keeps execution and state collection separate:
- `run_csim.tcl` performs the HLS action
- `get_sim_state.tcl` inspects generated outputs and summarizes the result
- `llm_review.sh` runs a final report-only AI review over the structured state JSON

## Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `project_name` | Yes | — | HLS project name |
| `part` | Yes | — | FPGA part number |
| `project_dir` | Yes | — | Absolute path to parent directory |
| `top_function` | Yes | — | Top-level C/C++ function name |
| `sources_json` | Yes | — | JSON array of source file objects |
| `testbench_json` | No | `[]` | JSON array of testbench file objects |
| `solution_name` | No | `solution1` | Solution name |
| `clock_period` | No | `10` | Clock period in nanoseconds |

## Output shape

`get_sim_state.tcl` returns a structured snapshot including:
- `csim_status` (`pass`, `fail`, or `not_run`)
- `report_path`
- `step_log_path`
- `report_tail`
- `step_log_tail`
- `messages`

The final workflow output is the JSON produced by the review step, for example a concise `pass` / `warning` / `fail` summary with issues and no automatic patching.

## Notes

- The workflow assumes the HLS project is already initialized.
- Testbench files must already be registered in the project.
- The wrapper must continue to use result-file handoff rather than stdout scraping.
- The final AI review is report-only; it does not auto-apply patches.
