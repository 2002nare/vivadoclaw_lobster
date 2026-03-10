# apply_patch.tcl — Apply structured patch actions to Vitis HLS project
# Environment:
#   VITIS_HLS_PROJECT_DIR   — parent directory containing project
#   VITIS_HLS_PROJECT_NAME  — project name
#   VITIS_HLS_PATCHES_JSON  — JSON string containing patches array from AI review
#     [{"action": "add_source", "params": {"path": "..."}, "reason": "..."}, ...]
# Output (stdout): JSON with applied/failed counts
#
# Supported actions: add_source, remove_source, add_testbench,
#                    remove_testbench, set_top, set_part, set_clock

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc find_json_objects {input} {
    set items {}
    set len [string length $input]
    set i 0
    while {$i < $len} {
        set open [string first "\{" $input $i]
        if {$open == -1} break
        set depth 1
        set j [expr {$open + 1}]
        while {$j < $len && $depth > 0} {
            set ch [string index $input $j]
            if {$ch eq "\{"} {incr depth}
            if {$ch eq "\}"} {incr depth -1}
            incr j
        }
        if {$depth == 0} {
            lappend items [string range $input $open [expr {$j - 1}]]
        }
        set i $j
    }
    return $items
}

proc json_get {obj key} {
    set pattern "\"$key\"\\s*:\\s*\"(\[^\"\]*)\""
    if {[regexp $pattern $obj _ val]} {
        return $val
    }
    return ""
}

proc parse_patch_actions {input} {
    set actions {}
    set objects [find_json_objects $input]

    foreach obj $objects {
        set action [json_get $obj "action"]
        if {$action eq ""} continue

        set path [json_get $obj "path"]
        set function_name [json_get $obj "function_name"]
        set part [json_get $obj "part"]
        set clock_period [json_get $obj "clock_period_ns"]
        set reason [json_get $obj "reason"]

        lappend actions [list $action $path $function_name $part $clock_period $reason]
    }
    return $actions
}

proc main {} {
    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)

    set proj_path "$project_dir/$name"
    if {![file isdirectory $proj_path]} {
        puts "{\"ok\": false, \"error\": \"Project directory not found: $proj_path\"}"
        return
    }
    open_project $proj_path

    set patches_json $::env(VITIS_HLS_PATCHES_JSON)
    set actions [parse_patch_actions $patches_json]
    set applied 0
    set failed 0
    set errors {}

    foreach act $actions {
        set action [lindex $act 0]
        set path [lindex $act 1]
        set function_name [lindex $act 2]
        set part [lindex $act 3]
        set clock_period [lindex $act 4]
        set reason [lindex $act 5]

        if {[catch {
            switch -exact $action {
                "add_source" {
                    if {![file exists $path]} {
                        error "File not found: $path"
                    }
                    add_files $path
                }
                "remove_source" {
                    remove_files $path
                }
                "add_testbench" {
                    if {![file exists $path]} {
                        error "File not found: $path"
                    }
                    add_files -tb $path
                }
                "remove_testbench" {
                    remove_files -tb $path
                }
                "set_top" {
                    set_top $function_name
                }
                "set_part" {
                    set sol_name "solution1"
                    if {[info exists ::env(VITIS_HLS_SOLUTION_NAME)]} {
                        set sol_name $::env(VITIS_HLS_SOLUTION_NAME)
                    }
                    open_solution $sol_name
                    set_part $part
                    close_solution
                }
                "set_clock" {
                    set sol_name "solution1"
                    if {[info exists ::env(VITIS_HLS_SOLUTION_NAME)]} {
                        set sol_name $::env(VITIS_HLS_SOLUTION_NAME)
                    }
                    open_solution $sol_name
                    create_clock -period $clock_period
                    close_solution
                }
                default {
                    error "Unsupported action: $action"
                }
            }
            incr applied
        } err]} {
            incr failed
            lappend errors "$action: $err"
        }
    }

    close_project

    set err_json "\[\]"
    if {[llength $errors] > 0} {
        set err_items {}
        foreach e $errors {
            lappend err_items [json_escape $e]
        }
        set err_json "\[[join $err_items ", "]\]"
    }

    puts "{\"ok\": true, \"data\": {\"applied\": $applied, \"failed\": $failed, \"errors\": $err_json}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
