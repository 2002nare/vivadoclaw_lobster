# set_top.tcl — Set top function and write result JSON to file

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return $s
}

proc write_result {json_text} {
    set result_path $::env(VITIS_HLS_RESULT_JSON)
    set fp [open $result_path "w"]
    puts $fp $json_text
    close $fp
}

proc fail {msg} {
    set escaped [json_escape $msg]
    write_result "{\"ok\": false, \"error\": \"$escaped\"}"
    exit 1
}

proc main {} {
    if {![info exists ::env(VITIS_HLS_PROJECT_DIR)]} {
        fail "VITIS_HLS_PROJECT_DIR is not set"
    }
    if {![info exists ::env(VITIS_HLS_PROJECT_NAME)]} {
        fail "VITIS_HLS_PROJECT_NAME is not set"
    }
    if {![info exists ::env(VITIS_HLS_TOP_FUNCTION)]} {
        fail "VITIS_HLS_TOP_FUNCTION is not set"
    }

    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set top_function $::env(VITIS_HLS_TOP_FUNCTION)

    open_project "$project_dir/$name"
    set_top $top_function
    close_project

    set escaped_top [json_escape $top_function]
    write_result "{\"ok\": true, \"data\": {\"top_function\": \"$escaped_top\"}}"
    exit 0
}

if {[catch {main} err]} {
    fail $err
}
