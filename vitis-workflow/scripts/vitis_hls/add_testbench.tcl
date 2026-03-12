# add_testbench.tcl — Add testbench files to Vitis HLS project and write result JSON to file

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return $s
}

proc write_result {json_text} {
    set result_path $::env(VITIS_HLS_RESULT_JSON)
    set fp [open $result_path "w"]
    puts $fp $json_text
    close $fp
}

proc fail {msg} {
    set escaped [json_escape $msg]
    write_result "{\"ok\": false, \"error\": \"$escaped\"}"
    exit 1
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
    if {![info exists ::env(VITIS_HLS_PROJECT_DIR)]} {
        fail "VITIS_HLS_PROJECT_DIR is not set"
    }
    if {![info exists ::env(VITIS_HLS_PROJECT_NAME)]} {
        fail "VITIS_HLS_PROJECT_NAME is not set"
    }
    if {![info exists ::env(VITIS_HLS_TESTBENCH_JSON)]} {
        fail "VITIS_HLS_TESTBENCH_JSON is not set"
    }

    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    open_project "$project_dir/$name"

    set tb_json $::env(VITIS_HLS_TESTBENCH_JSON)
    set objects [find_json_objects $tb_json]
    set added 0
    set errors {}

    foreach obj $objects {
        set path [json_get $obj "path"]
        if {$path eq ""} { continue }

        if {![file exists $path]} {
            lappend errors "File not found: $path"
            continue
        }

        set normalized_path [file normalize $path]
        add_files -tb $normalized_path
        incr added
    }

    close_project

    if {[llength $errors] > 0} {
        set err_str [json_escape [join $errors "; "]]
        write_result "{\"ok\": true, \"data\": {\"added\": $added, \"warnings\": \"$err_str\"}}"
    } else {
        write_result "{\"ok\": true, \"data\": {\"added\": $added}}"
    }

    exit 0
}

if {[catch {main} err]} {
    fail $err
}
