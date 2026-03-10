# get_project_state.tcl — Collect Vitis HLS project state as JSON
# Environment:
#   VITIS_HLS_PROJECT_DIR  — parent directory containing project
#   VITIS_HLS_PROJECT_NAME — project name
# Output (stdout): JSON object matching project-state.schema.json

# --- JSON helper procs ---
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

# --- Main ---
proc get_project_state {} {
    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set proj_path "$project_dir/$name"

    # Verify project directory exists
    if {![file isdirectory $proj_path]} {
        puts "{\"ok\": false, \"error\": \"Project directory not found: $proj_path\"}"
        return
    }

    open_project $proj_path

    # --- Project info ---
    set project_json [json_obj [list \
        name [json_escape $name] \
        directory [json_escape $proj_path] \
    ]]

    # --- Source files ---
    set source_items {}
    if {[catch {
        set src_files [get_files -src]
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
            }
            lappend source_items [json_obj [list \
                path [json_escape $f] \
                type [json_escape $ftype] \
            ]]
        }
    } err]} {
        # Fallback: scan project directory for source files
        foreach pattern {*.c *.cpp *.cc *.cxx *.h *.hpp} {
            set files [glob -nocomplain -directory "$proj_path/src" $pattern]
            foreach f $files {
                set ext [string tolower [file extension $f]]
                set ftype "cpp"
                switch -exact $ext {
                    ".c"   { set ftype "c" }
                    ".h"   { set ftype "header" }
                    ".hpp" { set ftype "header" }
                }
                lappend source_items [json_obj [list \
                    path [json_escape $f] \
                    type [json_escape $ftype] \
                ]]
            }
        }
    }
    set sources_json [json_array $source_items]

    # --- Testbench files ---
    set tb_items {}
    if {[catch {
        set tb_files [get_files -tb]
        foreach f $tb_files {
            lappend tb_items [json_obj [list \
                path [json_escape $f] \
            ]]
        }
    } err]} {
        # Fallback: scan project directory for testbench files
        foreach pattern {*_tb.cpp *_test.cpp *_tb.c *_test.c tb_*.cpp test_*.cpp} {
            set files [glob -nocomplain -directory "$proj_path/testbench" $pattern]
            foreach f $files {
                lappend tb_items [json_obj [list \
                    path [json_escape $f] \
                ]]
            }
        }
    }
    set testbench_json [json_array $tb_items]

    # --- Solution info ---
    set solution_json "null"
    set solution_name ""
    if {[info exists ::env(VITIS_HLS_SOLUTION_NAME)]} {
        set solution_name $::env(VITIS_HLS_SOLUTION_NAME)
    } else {
        set solution_name "solution1"
    }

    if {[catch {
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
        # Solution does not exist yet
        set solution_json "null"
    }

    # --- Top function ---
    set top_function "null"
    catch {
        set top [get_top]
        if {$top ne ""} {
            set top_function [json_escape $top]
        }
    }

    # --- Diagnostic messages ---
    set message_items {}

    # Check: no source files
    if {[llength $source_items] == 0} {
        lappend message_items [json_obj [list \
            severity [json_escape "error"] \
            text [json_escape "No source files found in the project. Add C/C++ source files."] \
            id [json_escape "VITISCLAW-001"] \
        ]]
    }

    # Check: no testbench
    if {[llength $tb_items] == 0} {
        lappend message_items [json_obj [list \
            severity [json_escape "warning"] \
            text [json_escape "No testbench files found. C simulation (csim) and co-simulation (cosim) require a testbench."] \
            id [json_escape "VITISCLAW-002"] \
        ]]
    }

    # Check: no solution
    if {$solution_json eq "null"} {
        lappend message_items [json_obj [list \
            severity [json_escape "warning"] \
            text [json_escape "No solution configured. A solution with target part and clock period is required for synthesis."] \
            id [json_escape "VITISCLAW-003"] \
        ]]
    }

    # Check: no top function
    if {$top_function eq "null"} {
        lappend message_items [json_obj [list \
            severity [json_escape "warning"] \
            text [json_escape "Top function is not set. set_top must be called before synthesis."] \
            id [json_escape "VITISCLAW-004"] \
        ]]
    }

    set messages_json [json_array $message_items]

    # --- Assemble final JSON ---
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
    puts $result
}

# Execute
if {[catch {get_project_state} err]} {
    set escaped_err [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped_err\"}"
}
