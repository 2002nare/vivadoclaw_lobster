# Basys3 Board Reference

## FPGA
- **Vendor**: Xilinx
- **Family**: Artix-7
- **Part**: `xc7a35tcpg236-1` (CPG236 package, Commercial temp, speed grade -1)
- **NOT** `xc7a35ticsg324-1L` — that is Arty A7-35T (CSG324, Industrial)

## Clock
- 100 MHz oscillator → pin **W5**
- `create_clock -period 10.00 -waveform {0 5} [get_ports clk]`

## IO Standard
- All user I/O: **LVCMOS33**
- Config: `CONFIG_VOLTAGE 3.3`, `CFGBVS VCCO`

## Key Pin Map

### Buttons (active-high, directly active logic 1 when pressed)
| Signal | Pin | Note |
|--------|-----|------|
| btnC   | U18 | Center — commonly used as reset (invert for active-low) |
| btnU   | T18 | Up |
| btnL   | W19 | Left |
| btnR   | T17 | Right |
| btnD   | U17 | Down |

### Switches (active-high)
| Signal   | Pin |
|----------|-----|
| sw[0]    | V17 |
| sw[1]    | V16 |
| sw[2]    | W16 |
| sw[3]    | W17 |
| sw[4]    | W15 |
| sw[5]    | V15 |
| sw[6]    | W14 |
| sw[7]    | W13 |
| sw[8]    | V2  |
| sw[9]    | T3  |
| sw[10]   | T2  |
| sw[11]   | R3  |
| sw[12]   | W2  |
| sw[13]   | U1  |
| sw[14]   | T1  |
| sw[15]   | R2  |

### LEDs
| Signal   | Pin |
|----------|-----|
| led[0]   | U16 |
| led[1]   | E19 |
| led[2]   | U19 |
| led[3]   | V19 |
| led[4]   | W18 |
| led[5]   | U15 |
| led[6]   | U14 |
| led[7]   | V14 |
| led[8]   | V13 |
| led[9]   | V3  |
| led[10]  | W3  |
| led[11]  | U3  |
| led[12]  | P3  |
| led[13]  | N3  |
| led[14]  | P1  |
| led[15]  | L1  |

### 7-Segment Display
| Signal | Pin | Note |
|--------|-----|------|
| seg[0] | W7  | CA |
| seg[1] | W6  | CB |
| seg[2] | U8  | CC |
| seg[3] | V8  | CD |
| seg[4] | U5  | CE |
| seg[5] | V5  | CF |
| seg[6] | U7  | CG |
| dp     | V7  | Decimal point |
| an[0]  | U2  | Anode 0 (active-low) |
| an[1]  | U4  | Anode 1 |
| an[2]  | V4  | Anode 2 |
| an[3]  | W4  | Anode 3 |

### USB-RS232 (USB-UART bridge)
| Signal | Pin | Direction (FPGA perspective) |
|--------|-----|-----------------------------|
| RsTx   | A18 | Output (FPGA → PC) |
| RsRx   | B18 | Input  (PC → FPGA) |

### Pmod Headers
| Header | Pins (1-4, 7-10) |
|--------|-------------------|
| JA     | J1, L2, J2, G2, H1, K2, H2, G3 |
| JB     | A14, A16, B15, B16, A15, A17, C15, C16 |
| JC     | K17, M18, N17, P18, L17, M19, P17, R18 |
| JXADC  | J3, L3, M2, N2, K3, M3, M1, N1 |

### VGA
| Signal      | Pins |
|-------------|------|
| vgaRed[3:0] | G19, H19, J19, N19 |
| vgaBlue[3:0]| N18, L18, K18, J18 |
| vgaGreen[3:0]| J17, H17, G17, D17 |
| Hsync       | P19 |
| Vsync       | R19 |

### Other
| Signal   | Pin | Note |
|----------|-----|------|
| PS2Clk   | C17 | USB HID, needs PULLUP |
| PS2Data  | B17 | USB HID, needs PULLUP |
| QspiDB[3:0] | D18, D19, G18, F18 | Quad SPI Flash |
| QspiCSn  | K19 | Quad SPI CS |

## Bitstream Config
```tcl
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
```

## XDC Source
- Master XDC: [Digilent Basys-3-Master.xdc](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc)
