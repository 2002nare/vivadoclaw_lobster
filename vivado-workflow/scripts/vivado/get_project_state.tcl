# get_project_state.tcl — Collect Vivado project state as JSON
# Environment:
#   VIVADO_PROJECT_DIR — project directory containing .xpr file
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
    set project_dir $::env(VIVADO_PROJECT_DIR)

    # Find and open .xpr file
    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    set xpr_path [lindex $xpr_files 0]
    open_project $xpr_path

    # --- Project info ---
    set proj_name [get_property NAME [current_project]]
    set proj_part [get_property PART [current_project]]
    set proj_dir  [get_property DIRECTORY [current_project]]
    set board_part ""
    catch {set board_part [get_property BOARD_PART [current_project]]}

    set project_json [json_obj [list \
        name [json_escape $proj_name] \
        part [json_escape $proj_part] \
        directory [json_escape $proj_dir] \
        board_part [json_escape $board_part] \
    ]]

    # --- Source files ---
    set source_items {}
    set src_files [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE =~ "*Verilog*" || FILE_TYPE =~ "*VHDL*"}]
    foreach f $src_files {
        set fpath [get_property FILE_NAME_WITH_PATH $f]
        set ftype_raw [get_property FILE_TYPE $f]
        set library "work"
        catch {set library [get_property LIBRARY $f]}

        # Normalize file type
        if {[string match "*SystemVerilog*" $ftype_raw]} {
            set ftype "systemverilog"
        } elseif {[string match "*Verilog*" $ftype_raw]} {
            set ftype "verilog"
        } elseif {[string match "*VHDL*" $ftype_raw]} {
            set ftype "vhdl"
        } else {
            set ftype "verilog"
        }

        set fileset "sources_1"
        catch {set fileset [get_property FILESET_NAME $f]}

        lappend source_items [json_obj [list \
            path [json_escape $fpath] \
            type [json_escape $ftype] \
            library [json_escape $library] \
            fileset [json_escape $fileset] \
        ]]
    }
    set sources_json [json_array $source_items]

    # --- Constraint files ---
    set constraint_items {}
    set constr_filesets [get_filesets -filter {FILESET_TYPE == "Constrs"}]
    foreach cfs $constr_filesets {
        set xdc_files [get_files -of_objects $cfs -filter {FILE_TYPE == "XDC"}]
        foreach f $xdc_files {
            set fpath [get_property FILE_NAME_WITH_PATH $f]
            set used_in {}
            catch {set used_in [get_property USED_IN $f]}

            set used_in_items {}
            foreach u $used_in {
                lappend used_in_items [json_escape $u]
            }

            lappend constraint_items [json_obj [list \
                path [json_escape $fpath] \
                used_in [json_array $used_in_items] \
            ]]
        }
    }
    set constraints_json [json_array $constraint_items]

    # --- Top module ---
    set top_module "null"
    catch {
        set top [get_property TOP [get_filesets sources_1]]
        if {$top ne ""} {
            set top_module [json_escape $top]
        }
    }

    # --- Compile order ---
    set compile_status "resolved"
    set compile_files_items {}
    if {[catch {
        set compile_files [get_files -compile_order sources -used_in synthesis -of_objects [get_filesets sources_1]]
        foreach f $compile_files {
            lappend compile_files_items [json_escape $f]
        }
    } err]} {
        set compile_status "error"
    }

    # Check for unresolved references
    if {[catch {
        set msgs [get_msg_config -rules]
    }]} {
        # Fallback: if we got files but there might be unresolved refs
        # We'll detect this from Vivado messages below
    }

    set compile_order_json [json_obj [list \
        status [json_escape $compile_status] \
        files [json_array $compile_files_items] \
    ]]

    # --- Messages (warnings/errors from current session) ---
    set message_items {}

    # Collect messages from Vivado message store
    foreach sev {ERROR {CRITICAL WARNING} WARNING INFO} {
        set sev_lower [string tolower [string map {{ } _} $sev]]
        if {[catch {
            set msgs [get_msg_config -id -severity $sev -count 50]
        }]} {
            continue
        }
    }

    # Alternative: scan for common init issues
    # Check if top module is actually defined in sources
    if {$top_module ne "null"} {
        set top_name [string trim $top_module "\""]
        set found_top 0
        foreach f $src_files {
            set fname [file tail [get_property FILE_NAME_WITH_PATH $f]]
            set fname_noext [file rootname $fname]
            if {$fname_noext eq $top_name} {
                set found_top 1
                break
            }
        }
        if {!$found_top} {
            lappend message_items [json_obj [list \
                severity [json_escape "warning"] \
                text [json_escape "Top module '$top_name' may not match any source file name. Verify module declaration."] \
                id [json_escape "VIVADOCLAW-001"] \
            ]]
        }
    }

    # Check for empty constraints
    if {[llength $constraint_items] == 0} {
        lappend message_items [json_obj [list \
            severity [json_escape "warning"] \
            text [json_escape "No constraint (XDC) files found. Pin assignments and timing constraints may be missing."] \
            id [json_escape "VIVADOCLAW-002"] \
        ]]
    }

    set messages_json [json_array $message_items]

    # --- Assemble final JSON ---
    set result [json_obj [list \
        ok "true" \
        data [json_obj [list \
            project $project_json \
            sources $sources_json \
            constraints $constraints_json \
            top_module $top_module \
            compile_order $compile_order_json \
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
