# get_synth_state.tcl — Collect Vitis HLS synthesis state and write result JSON to file

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
    if {$text eq ""} { return "" }
    set lines [split $text "\n"]
    set total [llength $lines]
    set start [expr {$total - $count}]
    if {$start < 0} { set start 0 }
    return [join [lrange $lines $start end] "\n"]
}

proc xml_tag_value {xml tag} {
    if {[regexp "<$tag>(.*?)</$tag>" $xml _ val]} {
        return $val
    }
    return ""
}

proc detect_csynth_status {report_text step_log_text} {
    set combined "$report_text\n$step_log_text"
    if {[regexp {Finished Command csynth_design} $combined] && [regexp {Estimated Fmax:} $combined]} {
        return "pass"
    }
    if {[regexp {ERROR:|csynth_design failed|Cannot find any design unit to elaborate|Error in linking the design} $combined]} {
        return "fail"
    }
    return "not_run"
}

proc collect_messages {report_text step_log_text} {
    set items {}
    set combined "$report_text\n$step_log_text"

    if {[regexp {Estimated Fmax: ([0-9.]+) MHz} $combined _ fmax]} {
        lappend items [json_obj [list \
            severity [json_escape "info"] \
            text [json_escape "Estimated Fmax: $fmax MHz"] \
            id [json_escape "VITISCLAW-CSYNTH-INFO-001"] \
        ]]
    }
    if {[regexp {Loop Constraint Status: All loop constraints were satisfied} $combined]} {
        lappend items [json_obj [list \
            severity [json_escape "info"] \
            text [json_escape "All loop constraints were satisfied"] \
            id [json_escape "VITISCLAW-CSYNTH-INFO-002"] \
        ]]
    }
    if {[regexp {Cannot find any design unit to elaborate} $combined]} {
        lappend items [json_obj [list \
            severity [json_escape "error"] \
            text [json_escape "No design unit could be elaborated during csynth"] \
            id [json_escape "VITISCLAW-CSYNTH-ERR-001"] \
        ]]
    }
    if {[regexp {Error in linking the design} $combined]} {
        lappend items [json_obj [list \
            severity [json_escape "error"] \
            text [json_escape "Design linking failed during csynth"] \
            id [json_escape "VITISCLAW-CSYNTH-ERR-002"] \
        ]]
    }

    return [json_array $items]
}

proc main {} {
    if {![info exists ::env(VITIS_HLS_PROJECT_DIR)]} { fail "VITIS_HLS_PROJECT_DIR is not set" }
    if {![info exists ::env(VITIS_HLS_PROJECT_NAME)]} { fail "VITIS_HLS_PROJECT_NAME is not set" }
    if {![info exists ::env(VITIS_HLS_SOLUTION_NAME)]} { fail "VITIS_HLS_SOLUTION_NAME is not set" }

    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set solution_name $::env(VITIS_HLS_SOLUTION_NAME)
    set proj_path "$project_dir/$name"
    set solution_dir "$proj_path/$solution_name"
    set report_dir "$solution_dir/syn/report"

    set report_path ""
    foreach candidate [list "$report_dir/${::env(VITIS_HLS_TOP_FUNCTION)}_csynth.xml" "$report_dir/csynth.xml"] {
        if {[file exists $candidate]} {
            set report_path $candidate
            break
        }
    }

    set solution_log_path "$solution_dir/solution1.log"
    if {[file exists "$solution_dir/${solution_name}.log"]} {
        set solution_log_path "$solution_dir/${solution_name}.log"
    }

    set step_log_path ""
    if {[info exists ::env(VITIS_HLS_RUN_DIR)]} {
        set run_logs [lsort [glob -nocomplain -directory $::env(VITIS_HLS_RUN_DIR) run_csynth_*.log]]
        if {[llength $run_logs] > 0} {
            set step_log_path [lindex $run_logs end]
        }
    }
    if {$step_log_path eq "" && [info exists ::env(VITIS_HLS_STEP_LOG)]} {
        set step_log_path $::env(VITIS_HLS_STEP_LOG)
    }

    set report_text [read_file_if_exists $report_path]
    set step_log_text [read_file_if_exists $step_log_path]
    set solution_log_text [read_file_if_exists $solution_log_path]
    set csynth_status [detect_csynth_status $report_text $step_log_text]

    set estimated_clock [xml_tag_value $report_text "EstimatedClockPeriod"]
    set target_clock [xml_tag_value $report_text "TargetClockPeriod"]
    set bram [xml_tag_value $report_text "BRAM_18K"]
    set ff [xml_tag_value $report_text "FF"]
    set lut [xml_tag_value $report_text "LUT"]
    set dsp [xml_tag_value $report_text "DSP"]
    set uram [xml_tag_value $report_text "URAM"]
    set latency_best [xml_tag_value $report_text "Best-caseLatency"]
    set latency_worst [xml_tag_value $report_text "Worst-caseLatency"]

    set estimated_fmax ""
    if {$estimated_clock ne ""} {
        catch {
            set estimated_fmax [format %.2f [expr {1000.0 / double($estimated_clock)}]]
        }
    }

    set summary "C synthesis has not been run yet"
    if {$csynth_status eq "pass"} {
        set summary "csynth completed successfully"
    } elseif {$csynth_status eq "fail"} {
        set summary "csynth failed"
    }

    set result [json_obj [list \
        ok "true" \
        data [json_obj [list \
            project [json_obj [list name [json_escape $name] directory [json_escape $proj_path]]] \
            solution [json_escape $solution_name] \
            csynth_status [json_escape $csynth_status] \
            summary [json_escape $summary] \
            report_path [json_escape $report_path] \
            solution_log_path [json_escape $solution_log_path] \
            step_log_path [json_escape $step_log_path] \
            target_clock_ns [json_escape $target_clock] \
            estimated_clock_ns [json_escape $estimated_clock] \
            estimated_fmax_mhz [json_escape $estimated_fmax] \
            latency_cycles [json_obj [list min [json_escape $latency_best] max [json_escape $latency_worst]]] \
            resource_summary [json_obj [list BRAM_18K [json_escape $bram] DSP [json_escape $dsp] FF [json_escape $ff] LUT [json_escape $lut] URAM [json_escape $uram]]] \
            report_tail [json_escape [tail_lines $solution_log_text 40]] \
            step_log_tail [json_escape [tail_lines $step_log_text 40]] \
            messages [collect_messages $report_text $step_log_text] \
        ]] \
    ]]

    write_result $result
    exit 0
}

if {[catch {main} err]} {
    fail $err
}
