# Domain Knowledge

Hardware design reference data for agents and humans.
This knowledge is board/tool/protocol-specific and reusable across projects.

## Structure
- `boards/` — FPGA board references (part numbers, pin maps, XDC data)
- `tools/` — EDA tool notes (Vivado, Vitis, simulators)
- `protocols/` — Communication protocol references (UART, SPI, AXI, etc.)

## Usage
- Agents should consult relevant files here when generating RTL, testbenches, or constraints
- Spec files may reference these via `agent_guidance.generation_hints`
