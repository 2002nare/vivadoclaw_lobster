# get_export_state.tcl — Collect Vitis HLS export state and write result JSON to file

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

proc detect_export_status {step_log_text vivado_log_text} {
    set combined "$step_log_text\n$vivado_log_text"
    if {[regexp {Generated output file .*export.zip} $combined] || [regexp {Created IP archive } $combined]} {
        return "pass"
    }
    if {[regexp {ERROR:|export_design failed|failed} $combined]} {
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
    set export_format "ip_catalog"
    if {[info exists ::env(VITIS_HLS_EXPORT_FORMAT)] && $::env(VITIS_HLS_EXPORT_FORMAT) ne ""} {
        set export_format $::env(VITIS_HLS_EXPORT_FORMAT)
    }

    set proj_path "$project_dir/$name"
    set solution_dir "$proj_path/$solution_name"
    set impl_dir "$solution_dir/impl"
    set ip_dir "$impl_dir/ip"
    set export_zip "$impl_dir/export.zip"
    set component_xml "$ip_dir/component.xml"
    set vivado_log "$ip_dir/vivado.log"

    set ip_archive ""
    set archives [glob -nocomplain -directory $ip_dir *.zip]
    if {[llength $archives] > 0} {
        set ip_archive [lindex $archives 0]
    }

    set step_log_path ""
    if {[info exists ::env(VITIS_HLS_RUN_DIR)]} {
        set run_logs [lsort [glob -nocomplain -directory $::env(VITIS_HLS_RUN_DIR) export_design_*.log]]
        if {[llength $run_logs] > 0} {
            set step_log_path [lindex $run_logs end]
        }
    }
    if {$step_log_path eq "" && [info exists ::env(VITIS_HLS_STEP_LOG)]} {
        set step_log_path $::env(VITIS_HLS_STEP_LOG)
    }

    set step_log_text [read_file_if_exists $step_log_path]
    set vivado_log_text [read_file_if_exists $vivado_log]
    set export_status [detect_export_status $step_log_text $vivado_log_text]

    set summary "RTL/IP export has not been run yet"
    if {$export_status eq "pass"} {
        set summary "export completed successfully"
    } elseif {$export_status eq "fail"} {
        set summary "export failed"
    }

    set message_items {}
    if {[file exists $component_xml]} {
        lappend message_items [json_obj [list severity [json_escape "info"] text [json_escape "IP component.xml generated"] id [json_escape "VITISCLAW-EXPORT-INFO-001"]]]
    }
    if {[file exists $export_zip]} {
        lappend message_items [json_obj [list severity [json_escape "info"] text [json_escape "export.zip generated"] id [json_escape "VITISCLAW-EXPORT-INFO-002"]]]
    }
    if {$ip_archive ne ""} {
        lappend message_items [json_obj [list severity [json_escape "info"] text [json_escape "Packaged IP archive generated"] id [json_escape "VITISCLAW-EXPORT-INFO-003"]]]
    }

    set result [json_obj [list \
        ok "true" \
        data [json_obj [list \
            project [json_obj [list name [json_escape $name] directory [json_escape $proj_path]]] \
            solution [json_escape $solution_name] \
            format [json_escape $export_format] \
            export_status [json_escape $export_status] \
            summary [json_escape $summary] \
            output_path [json_escape $impl_dir] \
            export_zip [json_escape $export_zip] \
            ip_dir [json_escape $ip_dir] \
            component_xml [json_escape $component_xml] \
            ip_archive [json_escape $ip_archive] \
            vivado_log_path [json_escape $vivado_log] \
            step_log_path [json_escape $step_log_path] \
            vivado_log_tail [json_escape [tail_lines $vivado_log_text 40]] \
            step_log_tail [json_escape [tail_lines $step_log_text 40]] \
            messages [json_array $message_items] \
        ]] \
    ]]

    write_result $result
    exit 0
}

if {[catch {main} err]} {
    fail $err
}
