# add_sim_sources.tcl — Add source files to Vivado simulation fileset
# Environment:
#   VIVADO_PROJECT_DIR    — project directory containing .xpr
#   VIVADO_SIM_SOURCES_JSON — JSON array of source objects
#     [{"path": "/abs/path/to/tb.v", "type": "verilog"}, ...]
#   VIVADO_SIM_FILESET    — (optional) simulation fileset name (default: "sim_1")
#   VIVADO_SIM_TOP        — (optional) simulation top module to set
# Output (stdout): JSON with added file count

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

proc main {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)
    set sim_fileset [expr {[info exists ::env(VIVADO_SIM_FILESET)] ? $::env(VIVADO_SIM_FILESET) : "sim_1"}]

    # Open project
    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    set added 0
    set errors {}

    # --- Auto-add all RTL sources from sources_1 to sim fileset ---
    set auto_added 0
    if {[catch {
        set rtl_files [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE =~ "*Verilog*" || FILE_TYPE =~ "*VHDL*"}]
        foreach f $rtl_files {
            set fpath [get_property NAME $f]
            if {[catch {add_files -fileset $sim_fileset $fpath}]} {
                # already in fileset, skip
            } else {
                incr auto_added
            }
        }
    }]} {
        # no sources_1 files
    }

    # --- Add user-specified sim sources (testbenches etc.) ---
    set sources_json $::env(VIVADO_SIM_SOURCES_JSON)
    set objects [find_json_objects $sources_json]

    foreach obj $objects {
        set path [json_get $obj "path"]
        set type [json_get $obj "type"]

        if {$type eq ""} { set type "verilog" }
        if {$path eq ""} { continue }

        if {![file exists $path]} {
            lappend errors "File not found: $path"
            continue
        }

        # Add file to sim fileset
        add_files -fileset $sim_fileset $path

        # Map type string to Vivado FILE_TYPE
        switch -exact $type {
            "systemverilog" { set vivado_type "SystemVerilog" }
            "vhdl"          { set vivado_type "VHDL" }
            default         { set vivado_type "Verilog" }
        }

        set file_obj [get_files -of_objects [get_filesets $sim_fileset] $path]
        set_property FILE_TYPE $vivado_type $file_obj

        incr added
    }

    # Set sim top if provided
    if {[info exists ::env(VIVADO_SIM_TOP)] && $::env(VIVADO_SIM_TOP) ne ""} {
        set_property TOP $::env(VIVADO_SIM_TOP) [get_filesets $sim_fileset]
    }

    close_project

    if {[llength $errors] > 0} {
        set err_str [join $errors "; "]
        puts "{\"ok\": true, \"data\": {\"added\": $added, \"auto_added_from_sources_1\": $auto_added, \"warnings\": [json_escape $err_str]}}"
    } else {
        puts "{\"ok\": true, \"data\": {\"added\": $added, \"auto_added_from_sources_1\": $auto_added}}"
    }
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
