# spi_slave_basys3_from_spec

Spec-derived example outputs for SPI slave bring-up on Basys3.

## Source inputs used
- Spec YAML: `../spec/spi_slave_bfm.spec.yaml`
- Spec JSON: `../spec/spi_slave_bfm.spec.json`
- TB plan YAML: `../plan/spi_slave_bfm_tb_plan.yaml`
- TB plan JSON: `../plan/spi_slave_bfm_tb_plan.json`

## Important status note
The source spec is **not final**.
The spec file currently declares:
- `status: draft`
- maturity fields set to draft

So this example should be treated as:
- a **spec-derived bring-up example**
- a **working implementation snapshot**
- **not** a full spec-complete final reference design

## Included generated/derived artifacts
- `rtl/spi_slave_core.sv`
- `rtl/basys3_spi_slave_top.sv`
- `constraints/basys3_spi_slave_wrapper.xdc`
- `tb/spi_slave_core_tb_stage0_3.sv`

## Basys3 SPI header mapping used by the wrapper
- `sclk` -> `JC2`
- `cs_n`  -> `JC1`
- `mosi`  -> `JC3`
- `miso`  -> `JC4`
