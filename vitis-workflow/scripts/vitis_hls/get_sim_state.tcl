# get_sim_state.tcl — Collect Vitis HLS C simulation state and write result JSON to file

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc json_array {items} {
    return "\[[join $items ", "]\]"
}

proc json_obj {pairs} {
    set parts {}
    foreach {k v} $pairs {
        lappend parts "[json_escape $k]: $v"
    }
    return "{[join $parts ", "]}"
}

proc write_result {json_text} {
    set result_path $::env(VITIS_HLS_RESULT_JSON)
    set fp [open $result_path "w"]
    puts $fp $json_text
    close $fp
}

proc fail {msg} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $msg]
    write_result "{\"ok\": false, \"error\": \"$escaped\"}"
    exit 1
}

proc read_file_if_exists {path} {
    if {![file exists $path]} {
        return ""
    }
    set fp [open $path "r"]
    set data [read $fp]
    close $fp
    return $data
}

proc tail_lines {text count} {
    if {$text eq ""} {
        return ""
    }
    set lines [split $text "\n"]
    set total [llength $lines]
    set start [expr {$total - $count}]
    if {$start < 0} { set start 0 }
    return [join [lrange $lines $start end] "\n"]
}

proc detect_csim_status {report_text step_log_text} {
    set combined "$report_text\n$step_log_text"
    if {[regexp {CSim done with 0 errors} $combined]} {
        return "pass"
    }
    if {[regexp {TEST PASSED} $combined]} {
        return "pass"
    }
    if {[regexp {CSIM finish} $combined] && ![regexp {0 errors} $combined]} {
        return "fail"
    }
    if {[regexp {ERROR:|TEST FAILED|No testbench files found|failed} $combined]} {
        return "fail"
    }
    return "not_run"
}

proc collect_messages {report_text step_log_text} {
    set items {}
    set combined "$report_text\n$step_log_text"

    if {[regexp {TEST PASSED} $combined]} {
        lappend items [json_obj [list \
            severity [json_escape "info"] \
            text [json_escape "Testbench reported TEST PASSED"] \
            id [json_escape "VITISCLAW-CSIM-INFO-001"] \
        ]]
    }
    if {[regexp {CSim done with 0 errors} $combined]} {
        lappend items [json_obj [list \
            severity [json_escape "info"] \
            text [json_escape "CSIM completed with 0 errors"] \
            id [json_escape "VITISCLAW-CSIM-INFO-002"] \
        ]]
    }
    if {[regexp {TEST FAILED} $combined]} {
        lappend items [json_obj [list \
            severity [json_escape "error"] \
            text [json_escape "Testbench reported TEST FAILED"] \
            id [json_escape "VITISCLAW-CSIM-ERR-001"] \
        ]]
    }
    if {[regexp {No testbench files found} $combined]} {
        lappend items [json_obj [list \
            severity [json_escape "error"] \
            text [json_escape "No testbench files found in project"] \
            id [json_escape "VITISCLAW-CSIM-ERR-002"] \
        ]]
    }

    return [json_array $items]
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
    set solution_dir "$proj_path/$solution_name"
    set report_dir "$solution_dir/csim/report"

    if {![file isdirectory $proj_path]} {
        fail "Project directory not found: $proj_path"
    }

    open_project $proj_path

    set source_items {}
    if {[catch {
        foreach f [get_files] {
            set ext [string tolower [file extension $f]]
            switch -exact $ext {
                ".c"   { set ftype "c" }
                ".cpp" { set ftype "cpp" }
                ".cc"  { set ftype "cpp" }
                ".cxx" { set ftype "cpp" }
                ".h"   { set ftype "header" }
                ".hpp" { set ftype "header" }
                ".hh"  { set ftype "header" }
                default { set ftype "other" }
            }
            if {$ftype eq "other"} { continue }
            lappend source_items [json_obj [list \
                path [json_escape $f] \
                type [json_escape $ftype] \
            ]]
        }
    } err]} {
        set source_items {}
    }

    set tb_items {}
    if {[catch {
        foreach f [get_files -tb] {
            lappend tb_items [json_obj [list \
                path [json_escape $f] \
            ]]
        }
    } err]} {
        set tb_items {}
    }

    catch {open_solution $solution_name}
    set top_function "null"
    catch {
        set top [get_top]
        if {$top ne ""} {
            set top_function [json_escape $top]
        }
    }
    catch {close_solution}
    catch {close_project}

    set report_path ""
    set report_glob [glob -nocomplain -directory $report_dir *.log]
    if {[llength $report_glob] > 0} {
        set report_path [lindex $report_glob 0]
    }

    set step_log_path ""
    if {[info exists ::env(VITIS_HLS_RUN_DIR)]} {
        set run_logs [lsort [glob -nocomplain -directory $::env(VITIS_HLS_RUN_DIR) run_csim_*.log]]
        if {[llength $run_logs] > 0} {
            set step_log_path [lindex $run_logs end]
        }
    }
    if {$step_log_path eq "" && [info exists ::env(VITIS_HLS_STEP_LOG)]} {
        set step_log_path $::env(VITIS_HLS_STEP_LOG)
    }

    set report_text [read_file_if_exists $report_path]
    set step_log_text [read_file_if_exists $step_log_path]
    set csim_status [detect_csim_status $report_text $step_log_text]

    set summary "C simulation has not been run yet"
    if {$csim_status eq "pass"} {
        set summary "csim completed successfully"
    } elseif {$csim_status eq "fail"} {
        set summary "csim failed"
    }

    set result [json_obj [list \
        ok "true" \
        data [json_obj [list \
            project [json_obj [list name [json_escape $name] directory [json_escape $proj_path]]] \
            solution [json_escape $solution_name] \
            top_function $top_function \
            sources [json_array $source_items] \
            testbench_files [json_array $tb_items] \
            csim_status [json_escape $csim_status] \
            summary [json_escape $summary] \
            report_path [json_escape $report_path] \
            step_log_path [json_escape $step_log_path] \
            report_tail [json_escape [tail_lines $report_text 20]] \
            step_log_tail [json_escape [tail_lines $step_log_text 20]] \
            messages [collect_messages $report_text $step_log_text] \
        ]] \
    ]]

    write_result $result
    exit 0
}

if {[catch {main} err]} {
    fail $err
}
