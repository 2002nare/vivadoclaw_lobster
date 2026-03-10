# set_top.tcl — Set top function for Vitis HLS project
# Environment:
#   VITIS_HLS_PROJECT_DIR   — parent directory containing project
#   VITIS_HLS_PROJECT_NAME  — project name
#   VITIS_HLS_TOP_FUNCTION  — top-level function name
# Output (stdout): JSON confirmation

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc main {} {
    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set top_function $::env(VITIS_HLS_TOP_FUNCTION)

    open_project "$project_dir/$name"

    set_top $top_function

    close_project

    puts "{\"ok\": true, \"data\": {\"top_function\": [json_escape $top_function]}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
