# run_simulation.tcl — Run Vivado behavioral simulation
# Environment:
#   VIVADO_PROJECT_DIR  — project directory containing .xpr file
#   VIVADO_SIM_TOP      — (optional) simulation top module, defaults to project top + "_tb" or project top
#   VIVADO_SIM_TIME     — (optional) simulation run time, e.g. "1000ns" (default: "1us")
#   VIVADO_SIM_FILESET  — (optional) simulation fileset name (default: "sim_1")
# Output (stdout): JSON with simulation result

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc run_sim {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)
    set sim_time [expr {[info exists ::env(VIVADO_SIM_TIME)] ? $::env(VIVADO_SIM_TIME) : "1us"}]
    set sim_fileset [expr {[info exists ::env(VIVADO_SIM_FILESET)] ? $::env(VIVADO_SIM_FILESET) : "sim_1"}]

    # Find and open project
    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    # Determine sim top module
    if {[info exists ::env(VIVADO_SIM_TOP)] && $::env(VIVADO_SIM_TOP) ne ""} {
        set sim_top $::env(VIVADO_SIM_TOP)
        set_property TOP $sim_top [get_filesets $sim_fileset]
    } else {
        set sim_top [get_property TOP [get_filesets $sim_fileset]]
        if {$sim_top eq ""} {
            # Fallback: use sources_1 top
            set sim_top [get_property TOP [get_filesets sources_1]]
        }
    }

    # Set simulation runtime
    set_property -name {xsim.simulate.runtime} -value $sim_time -objects [get_filesets $sim_fileset]

    # Launch simulation
    set sim_ok 1
    set sim_error ""
    if {[catch {
        launch_simulation -simset $sim_fileset
    } err]} {
        set sim_ok 0
        set sim_error $err
    }

    # Close simulation if running (prevents close_project errors)
    catch {close_sim}

    if {$sim_ok} {
        puts [subst "{\"ok\": true, \"sim_top\": [json_escape $sim_top], \"sim_time\": [json_escape $sim_time], \"fileset\": [json_escape $sim_fileset]}"]
    } else {
        puts [subst "{\"ok\": false, \"error\": [json_escape $sim_error], \"sim_top\": [json_escape $sim_top]}"]
    }

    catch {close_project}
}

if {[catch {run_sim} err]} {
    set escaped_err [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped_err\"}"
}
