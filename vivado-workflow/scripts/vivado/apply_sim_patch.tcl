# apply_sim_patch.tcl — Apply simulation patches from LLM review
# Environment:
#   VIVADO_PROJECT_DIR    — project directory containing .xpr file
#   VIVADO_PATCHES_JSON   — JSON string with patches array from LLM review
#   VIVADO_SIM_FILESET    — (optional) simulation fileset name (default: "sim_1")
# Output (stdout): JSON result

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc apply_sim_patches {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)
    set patches_json $::env(VIVADO_PATCHES_JSON)
    set sim_fileset [expr {[info exists ::env(VIVADO_SIM_FILESET)] ? $::env(VIVADO_SIM_FILESET) : "sim_1"}]

    # Find and open project
    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    # Parse patches from JSON using a temporary file + Vivado's built-in capabilities
    # Write JSON to temp file for parsing
    set tmpfile [file tempfile tmppath ".json"]
    puts $tmpfile $patches_json
    close $tmpfile

    # Use exec to parse with jq
    set patch_count 0
    set errors {}

    if {[catch {
        set num_patches [exec jq {.patches | length} $tmppath]
    } err]} {
        # No patches or parse error — treat as no-op
        set num_patches 0
    }

    for {set i 0} {$i < $num_patches} {incr i} {
        set action [exec jq -r ".patches\[$i\].action" $tmppath]
        set reason [exec jq -r ".patches\[$i\].reason" $tmppath]

        switch $action {
            "add_sim_source" {
                set path [exec jq -r ".patches\[$i\].params.path" $tmppath]
                set type [exec jq -r ".patches\[$i\].params.type // \"verilog\"" $tmppath]
                if {[catch {
                    add_files -fileset $sim_fileset $path
                } err]} {
                    lappend errors "add_sim_source($path): $err"
                } else {
                    incr patch_count
                }
            }
            "remove_sim_source" {
                set path [exec jq -r ".patches\[$i\].params.path" $tmppath]
                if {[catch {
                    remove_files -fileset $sim_fileset $path
                } err]} {
                    lappend errors "remove_sim_source($path): $err"
                } else {
                    incr patch_count
                }
            }
            "set_sim_top" {
                set module_name [exec jq -r ".patches\[$i\].params.module_name" $tmppath]
                if {[catch {
                    set_property TOP $module_name [get_filesets $sim_fileset]
                } err]} {
                    lappend errors "set_sim_top($module_name): $err"
                } else {
                    incr patch_count
                }
            }
            "set_sim_property" {
                set prop_name [exec jq -r ".patches\[$i\].params.property_name" $tmppath]
                set prop_value [exec jq -r ".patches\[$i\].params.property_value" $tmppath]
                if {[catch {
                    set_property $prop_name $prop_value [get_filesets $sim_fileset]
                } err]} {
                    lappend errors "set_sim_property($prop_name): $err"
                } else {
                    incr patch_count
                }
            }
            default {
                lappend errors "Unknown action: $action"
            }
        }
    }

    file delete $tmppath

    set error_count [llength $errors]
    if {$error_count > 0} {
        set error_str [join $errors "; "]
        puts [subst "{\"ok\": true, \"patches_applied\": $patch_count, \"errors\": $error_count, \"error_details\": [json_escape $error_str]}"]
    } else {
        puts "{\"ok\": true, \"patches_applied\": $patch_count, \"errors\": 0}"
    }

    close_project
}

if {[catch {apply_sim_patches} err]} {
    set escaped_err [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped_err\"}"
}
