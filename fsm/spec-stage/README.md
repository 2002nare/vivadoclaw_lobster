# spec-stage

Templates, schemas, examples, and domain knowledge for writing structured hardware design specs. These specs serve as the **single source of truth** between human designers and AI agents (RTL generation, review, repair).

## 3-Layer Spec Architecture

| Layer | Sections | Purpose |
|-------|----------|---------|
| **Layer 1: Intent** | `project`, `intent` | Why this design exists — goals, use cases, non-goals |
| **Layer 2: Design Contract** | `architecture`, `functional_spec`, `rules`, `performance` | What the design does — interfaces, behavior, constraints |
| **Layer 3: Build/Tool** | `target`, `tool_flow`, `implementation_constraints` | How to build it — FPGA part, tool versions, coding rules |
| **Cross-cutting** | `verification`, `agent_guidance`, `traceability` | How to verify and guide AI agents |

## Quick start

1. Copy the template: `cp templates/rtl_module.spec.yaml my_design.spec.yaml`
2. Fill in required fields (marked ★): `project`, `intent.goal`, `target.platform`, `architecture.interfaces`, `functional_spec.behavior`, `verification.pass_criteria`, `acceptance_criteria`
3. Progressively complete optional sections (`rules`, `performance`, `agent_guidance`, etc.)
4. See [fir_filter.spec.yaml](examples/fir_filter.spec.yaml) and [uart_transceiver.spec.yaml](examples/uart_transceiver.spec.yaml) for fully worked examples

## Supported design kinds

`rtl_module`, `rtl_system`, `axi_peripheral`, `streaming_pipeline`, `memory_mapped_accelerator`, `hls_kernel`, `block_design`, `soc_integration`, `board_io_design`, `verification_only`

## Structure

```
spec-stage/
  schemas/
    spec_base.schema.json    JSON Schema (v0.1) — validates all spec YAML files
  templates/
    rtl_module.spec.yaml     Blank template for rtl_module designs (fill in ★ fields)
  examples/
    fir_filter.spec.yaml     Complete example — pipelined FIR filter (DSP, streaming)
    uart_transceiver.spec.yaml  Complete example — full-duplex UART (FSM, serial protocol)
  domain-knowledge/
    boards/                  Board-specific info (pin maps, clocking, peripherals)
    protocols/               Protocol references (AXI, UART, SPI, I2C, ...)
    tools/                   Tool-specific knowledge (Vivado, Vitis, simulators)
```
