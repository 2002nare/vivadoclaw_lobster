# set_top.tcl — Set top module for Vivado project
# Environment:
#   VIVADO_PROJECT_DIR  — project directory containing .xpr
#   VIVADO_TOP_MODULE   — top module name
# Output (stdout): JSON confirmation

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc main {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)
    set top_module  $::env(VIVADO_TOP_MODULE)

    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    set_property TOP $top_module [get_filesets sources_1]

    set actual_top [get_property TOP [get_filesets sources_1]]

    close_project

    puts "{\"ok\": true, \"data\": {\"top_module\": [json_escape $actual_top]}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
