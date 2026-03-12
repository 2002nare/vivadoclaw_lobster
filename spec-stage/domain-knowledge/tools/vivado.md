# Vivado Domain Knowledge

## Tcl Tips
- File object path property: `NAME` (not `FILE_NAME_WITH_PATH`)
- `get_files` returns objects; use `get_property NAME $f` for path
- All data to Tcl scripts via env vars (Vivado batch mode doesn't forward stdin)
- JSON parsing in Tcl: use brace-depth counting (`find_json_objects`), NOT regex with `{}`

## Synthesis Inference
- DSP48: use `(* use_dsp = "yes" *)` attribute or let tool auto-infer from `*` operator
- BRAM: inferred from large arrays with synchronous read
- To avoid BRAM: keep arrays small or use `(* ram_style = "distributed" *)`

## Common Part Numbers
| Board | Part | Package | Temp |
|-------|------|---------|------|
| Basys3 | xc7a35tcpg236-1 | CPG236 | Commercial |
| Arty A7-35T | xc7a35ticsg324-1L | CSG324 | Industrial |
| Nexys A7-100T | xc7a100tcsg324-1 | CSG324 | Commercial |
| Zybo Z7-20 | xc7z020clg400-1 | CLG400 | Commercial |
