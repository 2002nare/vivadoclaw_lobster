# add_sources.tcl — Add RTL source files to Vivado project
# Environment:
#   VIVADO_PROJECT_DIR  — project directory containing .xpr
#   VIVADO_SOURCES_JSON — JSON array of source objects
#     [{"path": "/abs/path/to/file.v", "type": "verilog", "library": "work"}, ...]
# Output (stdout): JSON with added file count

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

# Extract JSON objects from a string using brace-depth counting
# (avoids regex with braces which breaks Vivado's Tcl brace matching)
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

# Extract a JSON string value by key from a flat JSON object string
proc json_get {obj key} {
    set pattern "\"$key\"\\s*:\\s*\"(\[^\"\]*)\""
    if {[regexp $pattern $obj _ val]} {
        return $val
    }
    return ""
}

proc main {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)

    # Open project
    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    # Parse source list from environment variable
    set sources_json $::env(VIVADO_SOURCES_JSON)
    set objects [find_json_objects $sources_json]
    set added 0
    set errors {}

    foreach obj $objects {
        set path [json_get $obj "path"]
        set type [json_get $obj "type"]
        set library [json_get $obj "library"]

        if {$type eq ""} { set type "verilog" }
        if {$library eq ""} { set library "work" }
        if {$path eq ""} { continue }

        if {![file exists $path]} {
            lappend errors "File not found: $path"
            continue
        }

        # Add file to sources_1 fileset
        add_files -fileset sources_1 $path

        # Map type string to Vivado FILE_TYPE
        switch -exact $type {
            "systemverilog" { set vivado_type "SystemVerilog" }
            "vhdl"          { set vivado_type "VHDL" }
            default         { set vivado_type "Verilog" }
        }

        set file_obj [get_files $path]
        set_property FILE_TYPE $vivado_type $file_obj
        set_property LIBRARY $library $file_obj

        incr added
    }

    close_project

    if {[llength $errors] > 0} {
        set err_str [join $errors "; "]
        puts "{\"ok\": true, \"data\": {\"added\": $added, \"warnings\": [json_escape $err_str]}}"
    } else {
        puts "{\"ok\": true, \"data\": {\"added\": $added}}"
    }
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
