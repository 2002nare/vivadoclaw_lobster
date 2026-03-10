# create_project.tcl — Create a new Vitis HLS project and write result JSON to file

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

proc main {} {
    if {![info exists ::env(VITIS_HLS_PROJECT_NAME)]} {
        fail "VITIS_HLS_PROJECT_NAME is not set"
    }
    if {![info exists ::env(VITIS_HLS_PROJECT_DIR)]} {
        fail "VITIS_HLS_PROJECT_DIR is not set"
    }

    set name $::env(VITIS_HLS_PROJECT_NAME)
    set dir  $::env(VITIS_HLS_PROJECT_DIR)
    file mkdir $dir

    set proj_path "$dir/$name"
    open_project -reset $proj_path
    close_project

    set escaped_proj_path [json_escape $proj_path]
    write_result "{\"ok\": true, \"data\": {\"project_dir\": \"$escaped_proj_path\"}}"
    exit 0
}

if {[catch {main} err]} {
    fail $err
}
