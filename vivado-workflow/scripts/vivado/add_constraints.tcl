# add_constraints.tcl — Add XDC constraint files to Vivado project
# Environment:
#   VIVADO_PROJECT_DIR      — project directory containing .xpr
#   VIVADO_CONSTRAINTS_JSON — JSON array of constraint objects
#     [{"path": "/abs/path/to/pins.xdc"}, ...]
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

    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    set constraints_json $::env(VIVADO_CONSTRAINTS_JSON)
    set objects [find_json_objects $constraints_json]
    set added 0
    set errors {}

    foreach obj $objects {
        set path [json_get $obj "path"]
        if {$path eq ""} { continue }

        if {![file exists $path]} {
            lappend errors "File not found: $path"
            continue
        }

        add_files -fileset constrs_1 $path
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
