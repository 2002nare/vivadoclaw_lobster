# Vitis HLS Init Workflows

## Current Recommendation

For reliable project initialization, use **`workflows/init-core.lobster` first**.

This repository now has two layers:

1. **`init-core.lobster`** — stable core initialization path
2. **`init.lobster`** — core init plus AI review / auto-patching (more experimental)

The core insight from testing was:

- `vitis_hls -f <tcl_script>` works reliably in batch mode
- the main stability issue was not Vitis HLS itself, but wrapper/orchestration behavior
- a thin batch wrapper plus result-file handoff is more reliable than parsing stdout JSON directly

---

## 1. Stable Path: `init-core.lobster`

### Flow

```text
create_project → add_sources → add_testbench → create_solution → set_top → final_state
```

### Why this is the recommended default

- uses `vitis_hls -f` in straightforward batch mode
- each Tcl step writes a **result JSON file**
- the shell wrapper returns that result file instead of scraping stdout
- avoids the earlier prompt/log parsing fragility
- validated end-to-end on a real `vector_add` HLS example

### Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `project_name` | Yes | — | HLS project name |
| `part` | Yes | — | FPGA part number (e.g., `xc7a35tcpg236-1`) |
| `project_dir` | Yes | — | Absolute path to parent directory |
| `top_function` | Yes | — | Top-level C/C++ function name |
| `sources_json` | Yes | — | JSON array of source files `[ {"path": "/abs/path.cpp"} ]` |
| `testbench_json` | No | `[]` | JSON array of testbench files `[ {"path": "/abs/path_tb.cpp"} ]` |
| `solution_name` | No | `solution1` | Solution name |
| `clock_period` | No | `10` | Clock period in nanoseconds |

### Example

```bash
~/lobster/bin/lobster.js run --file workflows/init-core.lobster --args-json '{
  "project_name":"hls_vector_add_core_test",
  "part":"xc7a35tcpg236-1",
  "project_dir":"/abs/path/to/project_parent",
  "top_function":"vector_add",
  "sources_json":"[{""path"":""/abs/path/vector_add.cpp""},{""path"":""/abs/path/vector_add.h""}]",
  "testbench_json":"[{""path"":""/abs/path/vector_add_tb.cpp""}]",
  "solution_name":"solution1",
  "clock_period":"10"
}'
```

---

## 2. Review Path: `init.lobster`

### Flow

```text
core init → state capture → AI review → auto-patch → re-review → final state
```

This path is useful when you want AI-assisted checking and patching, but it has more moving parts:

- OpenClaw connectivity
- review prompts / schemas
- patch application logic
- additional environment dependencies

### Recommendation

- use **`init-core.lobster`** to establish a known-good initialized project first
- use the review path only after the core path is behaving correctly in your environment

---

## Implementation Notes

### Why result files were adopted

Earlier iterations depended on extracting a JSON line from Tcl stdout. In practice, that was fragile.

The current core path uses this pattern instead:

- Tcl step performs the HLS action
- Tcl step writes structured JSON to `VITIS_HLS_RESULT_JSON`
- `scripts/vitis_hls_run.sh` returns that file content

This made the workflow much easier to reason about and debug.

### Wrapper design goals

`scripts/vitis_hls_run.sh` is now intended to stay thin:

- require `vitis_hls` to already be available in `PATH`
- create an isolated run directory
- execute `vitis_hls -f <script>`
- save a per-step log file
- return the step's result JSON file

### Vitis HLS CLI note

Validated behavior:

- `vitis_hls -i` → interactive CLI mode
- `vitis_hls -f script.tcl` → batch / non-interactive mode

The repository should prefer the second form for workflow execution.

---

## Known Good State (validated)

The following core init path was validated successfully:

- create project
- add sources
- add testbench
- create solution
- set top
- collect final project state

Validated final state included:

- source files visible
- testbench visible
- solution visible
- top function visible
- no remaining init-state warnings

---

## Next Suggested Extensions

After `init-core` stabilization, the next logical workflows are:

1. `sim.lobster` for `csim_design` ✅
2. `synth.lobster` for `csynth_design` ✅
3. `cosim.lobster` for `cosim_design` ✅
4. `export.lobster` for `export_design`

That ordering is recommended because it preserves the same separation of concerns:

- initialize first
- validate/simulate next
- synthesize after that
- export last

`sim.lobster` is now available as the first post-init workflow and follows the same pattern: batch Tcl execution, result-file handoff, structured state capture, and a final report-only AI review. `synth.lobster` now follows the same structure for `csynth_design`, including report extraction for timing/resource summaries. `cosim.lobster` extends the same pattern to `cosim_design`, including simulator log capture, cosim report parsing, and a final report-only AI review. See `docs/sim-workflow.md`, `docs/synth-workflow.md`, and `docs/cosim-workflow.md`.
