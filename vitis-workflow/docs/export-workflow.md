# Vitis HLS Export Workflow

## Overview

Run Vitis HLS RTL/IP export (`export_design`) using the same result-file handoff pattern established for `init-core.lobster`.

This is the final step after synthesis and co-simulation succeed: initialize the project, validate simulation, run synthesis, optionally run co-simulation, then run `workflows/export.lobster` to package the generated RTL as an exportable HLS IP artifact.

Current design keeps the flow simple:

```text
run_export → get_export_state → AI review
```

This keeps execution and state collection separate:
- `export_design.tcl` performs the HLS action
- `get_export_state.tcl` inspects generated export outputs and summarizes the result
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
| `export_format` | No | `ip_catalog` | Export format for `export_design` |

## Output shape

`get_export_state.tcl` returns a structured snapshot including:
- `export_status` (`pass`, `fail`, or `not_run`)
- `output_path`
- `export_zip`
- `ip_dir`
- `component_xml`
- `ip_archive`
- `vivado_log_path`
- `step_log_path`
- `messages`

The final workflow output is the JSON produced by the review step, for example a concise `pass` / `warning` / `fail` summary with issues and no automatic patching.

## Notes

- The workflow assumes the HLS project is already initialized and synthesized.
- The current export step works reliably when `export_design.tcl` executes from `project_dir`, consistent with synthesis/co-simulation path handling.
- The wrapper must continue to use result-file handoff rather than stdout scraping.
- The final AI review is report-only; it does not auto-apply patches.
