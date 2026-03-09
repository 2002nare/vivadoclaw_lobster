# apply_patch.tcl — Apply structured patch actions to Vivado project
# Environment:
#   VIVADO_PROJECT_DIR  — project directory containing .xpr
#   VIVADO_PATCHES_JSON — JSON array of patch action objects
#     [{"action": "add_source", "params": {"path": "...", "type": "verilog"}, "reason": "..."}, ...]
# Output (stdout): JSON with applied/failed counts
#
# Supported actions: add_source, remove_source, add_constraint,
#                    remove_constraint, set_top, set_property
# Failed child run reset is included for retry resilience.

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

# Extract JSON objects from a string using brace-depth counting
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
    # Find top-level objects in the patches array
    set objects [find_json_objects $input]

    foreach obj $objects {
        set action [json_get $obj "action"]
        if {$action eq ""} continue

        set path [json_get $obj "path"]
        set type [json_get $obj "type"]
        set library [json_get $obj "library"]
        set module_name [json_get $obj "module_name"]
        set property_name [json_get $obj "property_name"]
        set property_value [json_get $obj "property_value"]
        set object [json_get $obj "object"]
        set reason [json_get $obj "reason"]

        if {$library eq ""} { set library "work" }

        lappend actions [list $action $path $type $library $module_name $property_name $property_value $object $reason]
    }
    return $actions
}

proc reset_failed_runs {} {
    # Reset any failed child runs before retrying operations
    # This is critical: simple retry fails when child IP synth runs are in failed state
    if {[catch {
        set failed_runs [get_runs -quiet -filter "STATUS =~ *error*"]
        foreach run $failed_runs {
            reset_run $run
        }
    }]} {
        # Silently continue if no runs exist yet (init phase)
    }
}

proc main {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)

    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    # Reset failed runs for retry resilience
    reset_failed_runs

    set patches_json $::env(VIVADO_PATCHES_JSON)
    set actions [parse_patch_actions $patches_json]
    set applied 0
    set failed 0
    set errors {}

    foreach act $actions {
        set action [lindex $act 0]
        set path [lindex $act 1]
        set type [lindex $act 2]
        set library [lindex $act 3]
        set module_name [lindex $act 4]
        set property_name [lindex $act 5]
        set property_value [lindex $act 6]
        set object [lindex $act 7]
        set reason [lindex $act 8]

        if {[catch {
            switch -exact $action {
                "add_source" {
                    if {![file exists $path]} {
                        error "File not found: $path"
                    }
                    add_files -fileset sources_1 $path
                    switch -exact $type {
                        "systemverilog" { set_property FILE_TYPE "SystemVerilog" [get_files $path] }
                        "vhdl"          { set_property FILE_TYPE "VHDL" [get_files $path] }
                        default         { set_property FILE_TYPE "Verilog" [get_files $path] }
                    }
                    if {$library ne ""} {
                        set_property LIBRARY $library [get_files $path]
                    }
                }
                "remove_source" {
                    remove_files [get_files $path]
                }
                "add_constraint" {
                    if {![file exists $path]} {
                        error "File not found: $path"
                    }
                    add_files -fileset constrs_1 $path
                }
                "remove_constraint" {
                    remove_files [get_files -of_objects [get_filesets constrs_1] $path]
                }
                "set_top" {
                    set_property TOP $module_name [get_filesets sources_1]
                }
                "set_property" {
                    if {$object ne ""} {
                        set_property $property_name $property_value [get_files $object]
                    } else {
                        set_property $property_name $property_value [current_project]
                    }
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

    # Update compile order after patches
    catch {update_compile_order -fileset sources_1}

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
