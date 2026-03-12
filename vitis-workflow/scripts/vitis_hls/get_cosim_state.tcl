# get_cosim_state.tcl — Collect Vitis HLS co-simulation state and write result JSON to file

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
    if {![file exists $path]} { return "" }
    set fp [open $path "r"]
    set data [read $fp]
    close $fp
    return $data
}

proc tail_lines {text count} {
    if {$text eq ""} { return "" }
    set lines [split $text "\n"]
    set total [llength $lines]
    set start [expr {$total - $count}]
    if {$start < 0} { set start 0 }
    return [join [lrange $lines $start end] "\n"]
}

proc xml_messages {xml} {
    set items {}
    foreach line [split $xml "\n"] {
        if {[regexp {<Message severity="([^"]+)".*content="([^"]+)"} $line _ sev content]} {
            set normsev [string tolower $sev]
            if {$normsev ni {info warning error}} {
                set normsev "info"
            }
            lappend items [json_obj [list \
                severity [json_escape $normsev] \
                text [json_escape $content] \
            ]]
        }
    }
    return [json_array $items]
}

proc detect_cosim_status {rpt_text msg_xml xsim_text step_log_text} {
    set combined "$rpt_text\n$msg_xml\n$xsim_text\n$step_log_text"
    if {[regexp {co-simulation finished: PASS} $combined] || [regexp {\|\s*Verilog\|\s*Pass\|} $combined]} {
        return "pass"
    }
    if {[regexp {FAIL|failed|ERROR:} $combined]} {
        return "fail"
    }
    return "not_run"
}

proc main {} {
    if {![info exists ::env(VITIS_HLS_PROJECT_DIR)]} { fail "VITIS_HLS_PROJECT_DIR is not set" }
    if {![info exists ::env(VITIS_HLS_PROJECT_NAME)]} { fail "VITIS_HLS_PROJECT_NAME is not set" }
    if {![info exists ::env(VITIS_HLS_SOLUTION_NAME)]} { fail "VITIS_HLS_SOLUTION_NAME is not set" }

    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set solution_name $::env(VITIS_HLS_SOLUTION_NAME)
    set rtl_language "verilog"
    if {[info exists ::env(VITIS_HLS_RTL_LANGUAGE)] && $::env(VITIS_HLS_RTL_LANGUAGE) ne ""} {
        set rtl_language $::env(VITIS_HLS_RTL_LANGUAGE)
    }
    set simulator "xsim"
    if {[info exists ::env(VITIS_HLS_SIMULATOR)] && $::env(VITIS_HLS_SIMULATOR) ne ""} {
        set simulator $::env(VITIS_HLS_SIMULATOR)
    }

    set proj_path "$project_dir/$name"
    set solution_dir "$proj_path/$solution_name"
    set rpt_path "$solution_dir/sim/report/${::env(VITIS_HLS_TOP_FUNCTION)}_cosim.rpt"
    set msg_xml_path "$solution_dir/.autopilot/db/.message_cosim.xml"
    set xsim_log_path "$solution_dir/sim/$rtl_language/xsim.log"

    set step_log_path ""
    if {[info exists ::env(VITIS_HLS_RUN_DIR)]} {
        set run_logs [lsort [glob -nocomplain -directory $::env(VITIS_HLS_RUN_DIR) run_cosim_*.log]]
        if {[llength $run_logs] > 0} {
            set step_log_path [lindex $run_logs end]
        }
    }
    if {$step_log_path eq "" && [info exists ::env(VITIS_HLS_STEP_LOG)]} {
        set step_log_path $::env(VITIS_HLS_STEP_LOG)
    }

    set rpt_text [read_file_if_exists $rpt_path]
    set msg_xml [read_file_if_exists $msg_xml_path]
    set xsim_text [read_file_if_exists $xsim_log_path]
    set step_log_text [read_file_if_exists $step_log_path]

    set cosim_status [detect_cosim_status $rpt_text $msg_xml $xsim_text $step_log_text]
    set summary "C/RTL co-simulation has not been run yet"
    if {$cosim_status eq "pass"} {
        set summary "cosim completed successfully"
    } elseif {$cosim_status eq "fail"} {
        set summary "cosim failed"
    }

    set result [json_obj [list \
        ok "true" \
        data [json_obj [list \
            project [json_obj [list name [json_escape $name] directory [json_escape $proj_path]]] \
            solution [json_escape $solution_name] \
            rtl_language [json_escape $rtl_language] \
            simulator [json_escape $simulator] \
            cosim_status [json_escape $cosim_status] \
            summary [json_escape $summary] \
            report_path [json_escape $rpt_path] \
            message_xml_path [json_escape $msg_xml_path] \
            simulator_log_path [json_escape $xsim_log_path] \
            step_log_path [json_escape $step_log_path] \
            report_tail [json_escape [tail_lines $rpt_text 40]] \
            simulator_log_tail [json_escape [tail_lines $xsim_text 40]] \
            step_log_tail [json_escape [tail_lines $step_log_text 40]] \
            messages [xml_messages $msg_xml] \
        ]] \
    ]]

    write_result $result
    exit 0
}

if {[catch {main} err]} {
    fail $err
}
