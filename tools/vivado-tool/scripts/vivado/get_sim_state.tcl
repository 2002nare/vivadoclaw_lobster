# get_sim_state.tcl — Collect simulation state and results as JSON
# Environment:
#   VIVADO_PROJECT_DIR  — project directory containing .xpr file
#   VIVADO_SIM_FILESET  — (optional) simulation fileset name (default: "sim_1")
# Output (stdout): JSON object with simulation state

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

proc get_sim_state {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)
    set sim_fileset [expr {[info exists ::env(VIVADO_SIM_FILESET)] ? $::env(VIVADO_SIM_FILESET) : "sim_1"}]

    # Find and open project
    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    # --- Sim fileset info ---
    set sim_top ""
    catch {set sim_top [get_property TOP [get_filesets $sim_fileset]]}

    set sim_time ""
    catch {set sim_time [get_property {xsim.simulate.runtime} [get_filesets $sim_fileset]]}

    # --- Simulation source files (sim fileset only) ---
    set sim_source_items {}
    if {[catch {
        set sim_files [get_files -of_objects [get_filesets $sim_fileset]]
        foreach f $sim_files {
            set fpath [get_property NAME $f]
            set ftype_raw [get_property FILE_TYPE $f]
            lappend sim_source_items [json_obj [list \
                path [json_escape $fpath] \
                file_type [json_escape $ftype_raw] \
                fileset [json_escape $sim_fileset] \
            ]]
        }
    }]} {
        # no sim files
    }
    set sim_sources_json [json_array $sim_source_items]

    # --- RTL source files (inherited from sources_1) ---
    set rtl_source_items {}
    if {[catch {
        set rtl_files [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE =~ "*Verilog*" || FILE_TYPE =~ "*VHDL*"}]
        foreach f $rtl_files {
            set fpath [get_property NAME $f]
            set ftype_raw [get_property FILE_TYPE $f]
            lappend rtl_source_items [json_obj [list \
                path [json_escape $fpath] \
                file_type [json_escape $ftype_raw] \
                fileset [json_escape "sources_1"] \
            ]]
        }
    }]} {
        # no rtl files
    }
    set rtl_sources_json [json_array $rtl_source_items]

    # --- Check for testbench ---
    set has_testbench "false"
    if {$sim_top ne ""} {
        # Check if sim top differs from synthesis top (likely a testbench)
        set synth_top ""
        catch {set synth_top [get_property TOP [get_filesets sources_1]]}
        if {$sim_top ne $synth_top && $sim_top ne ""} {
            set has_testbench "true"
        }
    }

    # --- Simulation log (search multiple possible locations) ---
    # Vivado puts sim logs under {project_name}.sim/{fileset}/behav/xsim/
    set sim_log ""
    set proj_name [get_property NAME [current_project]]
    set run_dir [expr {[info exists ::env(VIVADO_RUN_DIR)] ? $::env(VIVADO_RUN_DIR) : "$project_dir/run"}]
    set log_candidates [list \
        "$project_dir/${proj_name}.sim/${sim_fileset}/behav/xsim/simulate.log" \
        "$project_dir/${proj_name}.sim/${sim_fileset}/behav/xsim/elaborate.log" \
        "$project_dir/${proj_name}.sim/${sim_fileset}/behav/xsim/compile.log" \
        "$project_dir/${sim_fileset}/behav/xsim/simulate.log" \
        "$run_dir/${sim_fileset}/behav/xsim/simulate.log" \
    ]
    foreach log_path $log_candidates {
        if {[file exists $log_path]} {
            set fp [open $log_path r]
            set sim_log [read $fp 10000]
            close $fp
            break
        }
    }

    # Extract errors/warnings from sim log
    set message_items {}
    if {$sim_log ne ""} {
        foreach line [split $sim_log "\n"] {
            if {[regexp -nocase {^(ERROR|FATAL):?\s*(.*)} $line -> sev msg]} {
                lappend message_items [json_obj [list \
                    severity [json_escape "error"] \
                    text [json_escape [string trim $msg]] \
                ]]
            } elseif {[regexp -nocase {^WARNING:?\s*(.*)} $line -> msg]} {
                lappend message_items [json_obj [list \
                    severity [json_escape "warning"] \
                    text [json_escape [string trim $msg]] \
                ]]
            }
        }
    }
    set messages_json [json_array $message_items]

    # --- Assemble result ---
    set result [json_obj [list \
        ok "true" \
        data [json_obj [list \
            sim_fileset [json_escape $sim_fileset] \
            sim_top [json_escape $sim_top] \
            sim_time [json_escape $sim_time] \
            has_testbench $has_testbench \
            sim_sources $sim_sources_json \
            rtl_sources $rtl_sources_json \
            sim_log [json_escape $sim_log] \
            messages $messages_json \
        ]] \
    ]]

    close_project
    puts $result
}

if {[catch {get_sim_state} err]} {
    set escaped_err [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped_err\"}"
}
