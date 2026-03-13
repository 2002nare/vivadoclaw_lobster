# run_csim.tcl — Run Vitis HLS C simulation and write result JSON to file

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

    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set solution_name $::env(VITIS_HLS_SOLUTION_NAME)
    set proj_path "$project_dir/$name"
    set log_path ""
    if {[info exists ::env(VITIS_HLS_STEP_LOG)]} {
        set log_path $::env(VITIS_HLS_STEP_LOG)
    }

    if {![file isdirectory $proj_path]} {
        fail "Project directory not found: $proj_path"
    }

    open_project $proj_path

    set tb_files {}
    catch { set tb_files [get_files -tb] }
    if {[llength $tb_files] == 0} {
        close_project
        fail "No testbench files found in project; add testbench files before running csim"
    }

    if {[catch {
        open_solution $solution_name
    } err]} {
        close_project
        fail "Failed to open solution '$solution_name': $err"
    }

    set csim_status "pass"
    set summary "csim_design completed successfully"
    set error_text ""

    if {[catch {
        csim_design
    } err]} {
        set csim_status "fail"
        set summary "csim_design failed"
        set error_text $err
    }

    catch {close_solution}
    catch {close_project}

    set escaped_solution [json_escape $solution_name]
    set escaped_status [json_escape $csim_status]
    set escaped_summary [json_escape $summary]
    set escaped_log [json_escape $log_path]

    if {$csim_status eq "pass"} {
        write_result "{\"ok\": true, \"data\": {\"csim_status\": \"$escaped_status\", \"solution\": \"$escaped_solution\", \"log_path\": \"$escaped_log\", \"summary\": \"$escaped_summary\", \"messages\": \[\]}}"
        exit 0
    }

    set escaped_error [json_escape $error_text]
    write_result "{\"ok\": false, \"error\": \"$escaped_error\", \"data\": {\"csim_status\": \"$escaped_status\", \"solution\": \"$escaped_solution\", \"log_path\": \"$escaped_log\", \"summary\": \"$escaped_summary\", \"messages\": [{\"severity\": \"error\", \"text\": \"$escaped_error\", \"id\": \"VITISCLAW-CSIM-001\"}]}}"
    exit 1
}

if {[catch {main} err]} {
    fail $err
}
