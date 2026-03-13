# get_project_state.tcl — Collect Vitis HLS project state and write result JSON to file

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

proc get_project_state {} {
    if {![info exists ::env(VITIS_HLS_PROJECT_DIR)]} {
        fail "VITIS_HLS_PROJECT_DIR is not set"
    }
    if {![info exists ::env(VITIS_HLS_PROJECT_NAME)]} {
        fail "VITIS_HLS_PROJECT_NAME is not set"
    }

    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set proj_path "$project_dir/$name"

    if {![file isdirectory $proj_path]} {
        fail "Project directory not found: $proj_path"
    }

    open_project $proj_path

    set project_json [json_obj [list \
        name [json_escape $name] \
        directory [json_escape $proj_path] \
    ]]

    set source_items {}
    if {[catch {
        set src_files [get_files]
        foreach f $src_files {
            set ftype "cpp"
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
    set sources_json [json_array $source_items]

    set tb_items {}
    if {[catch {
        set tb_files [get_files -tb]
        foreach f $tb_files {
            lappend tb_items [json_obj [list \
                path [json_escape $f] \
            ]]
        }
    } err]} {
        set tb_items {}
    }
    set testbench_json [json_array $tb_items]

    set solution_json "null"
    set solution_name "solution1"
    if {[info exists ::env(VITIS_HLS_SOLUTION_NAME)]} {
        set solution_name $::env(VITIS_HLS_SOLUTION_NAME)
    }

    if {![catch {
        open_solution $solution_name
        set part ""
        catch { set part [get_part] }
        set clock_period ""
        catch { set clock_period [get_clock_period] }
        if {$clock_period eq "" && [info exists ::env(VITIS_HLS_CLOCK_PERIOD)]} {
            set clock_period $::env(VITIS_HLS_CLOCK_PERIOD)
        }
        set solution_json [json_obj [list \
            name [json_escape $solution_name] \
            part [json_escape $part] \
            clock_period_ns [json_escape $clock_period] \
        ]]
        close_solution
    } err]} {
        # keep null
    }

    set top_function "null"
    catch {
        set top [get_top]
        if {$top ne ""} {
            set top_function [json_escape $top]
        }
    }

    set message_items {}
    if {[llength $source_items] == 0} {
        lappend message_items [json_obj [list \
            severity [json_escape "error"] \
            text [json_escape "No source files found in the project. Add C/C++ source files."] \
            id [json_escape "VITISCLAW-001"] \
        ]]
    }
    if {[llength $tb_items] == 0} {
        lappend message_items [json_obj [list \
            severity [json_escape "warning"] \
            text [json_escape "No testbench files found. C simulation (csim) and co-simulation (cosim) require a testbench."] \
            id [json_escape "VITISCLAW-002"] \
        ]]
    }
    if {$solution_json eq "null"} {
        lappend message_items [json_obj [list \
            severity [json_escape "warning"] \
            text [json_escape "No solution configured. A solution with target part and clock period is required for synthesis."] \
            id [json_escape "VITISCLAW-003"] \
        ]]
    }
    if {$top_function eq "null"} {
        lappend message_items [json_obj [list \
            severity [json_escape "warning"] \
            text [json_escape "Top function is not set. set_top must be called before synthesis."] \
            id [json_escape "VITISCLAW-004"] \
        ]]
    }
    set messages_json [json_array $message_items]

    set result [json_obj [list \
        ok "true" \
        data [json_obj [list \
            project $project_json \
            sources $sources_json \
            testbench_files $testbench_json \
            solution $solution_json \
            top_function $top_function \
            messages $messages_json \
        ]] \
    ]]

    close_project
    write_result $result
    exit 0
}

if {[catch {get_project_state} err]} {
    fail $err
}
