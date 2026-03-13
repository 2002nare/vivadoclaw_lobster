# vitis-tool

Lobster tools for Vitis HLS projects — project init, C simulation, HLS synthesis, C/RTL co-simulation, and RTL/IP export, each with AI-assisted review.

## Tools

| Tool | Description |
|------|-------------|
| [`init-core.lobster`](tools/init-core.lobster) | Stable HLS project initialization with result-file step handoff |
| [`init.lobster`](tools/init.lobster) | HLS init plus AI review/auto-patch layer |
| [`sim.lobster`](tools/sim.lobster) | C simulation (`csim_design`) with structured state capture and AI review |
| [`synth.lobster`](tools/synth.lobster) | HLS synthesis (`csynth_design`) with report extraction and AI review |
| [`cosim.lobster`](tools/cosim.lobster) | C/RTL co-simulation (`cosim_design`) with simulator/report capture and AI review |
| [`export.lobster`](tools/export.lobster) | RTL/IP export (`export_design`) with packaging artifact capture and AI review |

## Prerequisites

- `~/lobster/bin/lobster.js` — Lobster CLI
- `vitis_hls` — Vitis HLS (PATH, container)
- `jq`, `curl`
- `OPENCLAW_URL` and `OPENCLAW_TOKEN` environment variables

## Quick start

```bash
export OPENCLAW_URL=http://127.0.0.1:18789
export OPENCLAW_TOKEN=<your-token>

cd vitis-tool

~/lobster/bin/lobster.js run --file tools/init.lobster --args-json '{
  "project_name": "my_hls_proj",
  "part": "xc7a35tcpg236-1",
  "project_dir": "/home/appuser/projects/my_hls_proj",
  "top_function": "my_func",
  "sources_json": "[{\"path\":\"/home/appuser/src/my_func.cpp\"}]",
  "tb_sources_json": "[{\"path\":\"/home/appuser/src/my_func_tb.cpp\"}]"
}'
```

## Notes

- `vitis_hls -f <script.tcl>` works reliably in batch mode
- Result-file handoff between steps is more reliable than scraping JSON from stdout
- The stable init path is `tools/init-core.lobster`

## Structure

```
vitis-tool/
  tools/          Lobster tool definitions
  scripts/        Shell wrappers + Tcl scripts (one per HLS action)
  schemas/        JSON schemas for structured LLM output
  prompts/        LLM review prompts
  docs/           Per-tool documentation
```

## Documentation

- [init-tool.md](docs/init-tool.md) — Project initialization
- [sim-tool.md](docs/sim-tool.md) — C simulation
- [synth-tool.md](docs/synth-tool.md) — HLS synthesis
- [cosim-tool.md](docs/cosim-tool.md) — C/RTL co-simulation
- [export-tool.md](docs/export-tool.md) — RTL/IP export
