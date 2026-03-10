# create_solution.tcl — Create solution with part and clock and write result JSON to file

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
    if {![info exists ::env(VITIS_HLS_SOLUTION_NAME)]} {
        fail "VITIS_HLS_SOLUTION_NAME is not set"
    }
    if {![info exists ::env(VITIS_HLS_PART)]} {
        fail "VITIS_HLS_PART is not set"
    }
    if {![info exists ::env(VITIS_HLS_CLOCK_PERIOD)]} {
        fail "VITIS_HLS_CLOCK_PERIOD is not set"
    }

    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set solution_name $::env(VITIS_HLS_SOLUTION_NAME)
    set part $::env(VITIS_HLS_PART)
    set clock_period $::env(VITIS_HLS_CLOCK_PERIOD)

    open_project "$project_dir/$name"
    open_solution -reset $solution_name
    set_part $part
    create_clock -period $clock_period
    close_solution
    close_project

    set escaped_solution [json_escape $solution_name]
    set escaped_part [json_escape $part]
    set escaped_clock [json_escape $clock_period]
    write_result "{\"ok\": true, \"data\": {\"solution\": \"$escaped_solution\", \"part\": \"$escaped_part\", \"clock_period_ns\": \"$escaped_clock\"}}"
    exit 0
}

if {[catch {main} err]} {
    fail $err
}
