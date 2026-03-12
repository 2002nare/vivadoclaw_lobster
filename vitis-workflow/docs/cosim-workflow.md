# Vitis HLS Cosim Workflow

## Overview

Run Vitis HLS C/RTL co-simulation (`cosim_design`) using the same result-file handoff pattern established for `init-core.lobster`.

This is the recommended step after C synthesis succeeds: initialize the project, validate the C testbench path with `workflows/sim.lobster`, run synthesis with `workflows/synth.lobster`, then run `workflows/cosim.lobster` to compare C behavior against generated RTL.

Current design keeps the flow simple:

```text
run_cosim → get_cosim_state → AI review
```

This keeps execution and state collection separate:
- `run_cosim.tcl` performs the HLS action
- `get_cosim_state.tcl` inspects generated co-simulation outputs and summarizes the result
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
| `rtl_language` | No | `verilog` | RTL language for co-simulation |
| `simulator` | No | `xsim` | RTL simulator |

## Output shape

`get_cosim_state.tcl` returns a structured snapshot including:
- `cosim_status` (`pass`, `fail`, or `not_run`)
- `report_path`
- `message_xml_path`
- `simulator_log_path`
- `step_log_path`
- `report_tail`
- `simulator_log_tail`
- `messages`

The final workflow output is the JSON produced by the review step, for example a concise `pass` / `warning` / `fail` summary with issues and no automatic patching.

## Prerequisites

### Environment Variables (REQUIRED — must be set before running)

> **WARNING**: `OPENCLAW_URL` and `OPENCLAW_TOKEN` MUST be exported in the shell before running ANY workflow that uses `llm_review.sh`. The workflow WILL fail without them. Do NOT attempt to bypass, skip, or work around this requirement — there is no fallback. Set them explicitly every time.

```bash
export OPENCLAW_URL=http://127.0.0.1:18789    # OpenClaw gateway URL (REQUIRED)
export OPENCLAW_TOKEN=<your-token>              # Bearer token (REQUIRED)
```

### Required Tools

- `~/lobster/bin/lobster.js` — Lobster CLI
- `vitis_hls` — Vitis HLS (must be in PATH)
- `jq` — JSON processing
- `curl` — HTTP requests

## Notes

- The workflow assumes the HLS project is already initialized and synthesized.
- The current co-simulation step works reliably when `run_cosim.tcl` executes from `project_dir`, consistent with the synthesis-path behavior.
- The wrapper must continue to use result-file handoff rather than stdout scraping.
- The final AI review is report-only; it does not auto-apply patches.
