# Vitis HLS Init Workflow

## Overview

The `vitis-hls-init` workflow initializes a Vitis HLS project with AI-assisted review and auto-patching. It mirrors the `vivado-init` workflow pattern but targets Vitis HLS for C/C++ to RTL synthesis.

## Flow

```
create_project → add_sources → add_testbench → create_solution → set_top
    → state capture → AI review (cycle 1) → auto-patch
    → re-capture → AI review (cycle 2, strict) → final state
```

## Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `project_name` | Yes | — | HLS project name |
| `part` | Yes | — | FPGA part number (e.g., `xc7a35tcpg236-1`) |
| `project_dir` | Yes | — | Absolute path to parent directory |
| `top_function` | Yes | — | Top-level C/C++ function name |
| `sources_json` | Yes | — | JSON array of source files `[{"path": "/abs/path.cpp"}]` |
| `testbench_json` | No | `[]` | JSON array of testbench files `[{"path": "/abs/path_tb.cpp"}]` |
| `solution_name` | No | `solution1` | Solution name |
| `clock_period` | No | `10` | Clock period in nanoseconds |

## Environment Variables

Must be set before running:

- `OPENCLAW_URL` — OpenClaw gateway URL (default: `http://127.0.0.1:18789`)
- `OPENCLAW_TOKEN` — Bearer token for OpenClaw API

## AI Review

### Cycle 1 (Lenient)
- Checks: sources, testbench, top function, solution, part, synthesizability
- May propose patches: `add_source`, `remove_source`, `add_testbench`, `remove_testbench`, `set_top`, `set_part`, `set_clock`

### Cycle 2 (Strict)
- Verifies patches were applied
- Checks for regressions
- No patches proposed (report-only)

## Differences from Vivado Init Workflow

| Aspect | Vivado | Vitis HLS |
|--------|--------|-----------|
| Tool | `vivado -mode batch` | `vitis_hls -f` |
| Project | `.xpr` file | Directory-based |
| Sources | Verilog/VHDL filesets | C/C++ files |
| Constraints | XDC files | N/A (pragmas/directives) |
| Top entity | Module name | Function name |
| Clock | XDC constraint | `create_clock -period` |
| Compile order | `update_compile_order` | N/A (C compilation) |
| Testbench | Separate sim fileset | `add_files -tb` |
