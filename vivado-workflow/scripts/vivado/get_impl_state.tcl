# get_impl_state.tcl — Collect implementation/bitstream state as JSON for LLM review
# Environment:
#   VIVADO_PROJECT_DIR — base output directory used by impl_split workflow
#   VIVADO_TOP_MODULE  — top module / bitstream base name

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc slurp {path} {
    if {![file exists $path]} { return "" }
    set f [open $path r]
    set d [read $f]
    close $f
    return $d
}

proc main {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)
    set top $::env(VIVADO_TOP_MODULE)
    set run_dir "$project_dir/impl_split"
    set chk "$run_dir/checkpoints/post_route.dcp"
    set timing_rpt "$run_dir/reports/timing_post_route.rpt"
    set util_rpt "$run_dir/reports/util_post_route.rpt"
    set bit "$run_dir/bitstream/${top}.bit"

    set timing_log [slurp $timing_rpt]
    set util_log [slurp $util_rpt]

    set checkpoint_exists [expr {[file exists $chk] ? 1 : 0}]
    set timing_exists [expr {[file exists $timing_rpt] ? 1 : 0}]
    set util_exists [expr {[file exists $util_rpt] ? 1 : 0}]
    set bit_exists [expr {[file exists $bit] ? 1 : 0}]

    puts "{\"ok\": true, \"data\": {\"top_module\": [json_escape $top], \"project_dir\": [json_escape $project_dir], \"checkpoint_path\": [json_escape $chk], \"checkpoint_exists\": $checkpoint_exists, \"timing_report_path\": [json_escape $timing_rpt], \"timing_report_exists\": $timing_exists, \"timing_report\": [json_escape $timing_log], \"util_report_path\": [json_escape $util_rpt], \"util_report_exists\": $util_exists, \"util_report\": [json_escape $util_log], \"bitstream_path\": [json_escape $bit], \"bitstream_exists\": $bit_exists}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
