# write_bitstream_from_checkpoint.tcl — Re-open post-route checkpoint and write bitstream
# Environment:
#   VIVADO_PROJECT_DIR    — base output directory
#   VIVADO_TOP_MODULE     — top module name (used for output filename)
# Output: JSON with bitstream path

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc main {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)
    set top $::env(VIVADO_TOP_MODULE)
    set run_dir "$project_dir/impl_split"
    set chk "$run_dir/checkpoints/post_route.dcp"
    set bit_dir "$run_dir/bitstream"
    set bit_path "$bit_dir/${top}.bit"

    if {![file exists $chk]} {
        error "Checkpoint not found: $chk"
    }
    file mkdir $bit_dir

    open_checkpoint $chk
    write_bitstream -force $bit_path

    puts "{\"ok\": true, \"data\": {\"bitstream\": [json_escape $bit_path]}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
