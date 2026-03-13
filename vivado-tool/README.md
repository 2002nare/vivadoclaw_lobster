# vivado-tool

Lobster tools for Vivado FPGA projects — project init, behavioral simulation, and implementation/bitstream generation, each with AI-assisted review.

## Tools

| Tool | Description |
|------|-------------|
| [`init.lobster`](tools/init.lobster) | Create project, add sources/constraints, AI review + auto-patch |
| [`sim.lobster`](tools/sim.lobster) | Behavioral simulation with AI-assisted review |
| [`impl_split.lobster`](tools/impl_split.lobster) | Synth/impl/bitstream with checkpoint split and AI review |

## Prerequisites

- `~/lobster/bin/lobster.js` — Lobster CLI
- `vivado` — Vivado (PATH, container)
- `jq`, `curl`
- `OPENCLAW_URL` and `OPENCLAW_TOKEN` environment variables

## Quick start

```bash
export OPENCLAW_URL=http://127.0.0.1:18789
export OPENCLAW_TOKEN=<your-token>

cd vivado-tool

~/lobster/bin/lobster.js run --file tools/init.lobster --args-json '{
  "project_name": "my_proj",
  "part": "xc7a35tcpg236-1",
  "project_dir": "/home/appuser/projects/my_proj",
  "top_module": "top",
  "sources_json": "[{\"path\":\"/home/appuser/rtl/top.v\",\"type\":\"verilog\",\"library\":\"work\"}]"
}'
```

## Structure

```
vivado-tool/
  tools/          Lobster tool definitions
  scripts/        Shell wrappers + Tcl scripts (one per Vivado action)
  schemas/        JSON schemas for structured LLM output
  prompts/        LLM review prompts
  docs/           Per-tool documentation
```

## Documentation

- [init-tool.md](docs/init-tool.md) — Project initialization
- [sim-tool.md](docs/sim-tool.md) — Behavioral simulation
- [impl-split-tool.md](docs/impl-split-tool.md) — Implementation/bitstream split flow
