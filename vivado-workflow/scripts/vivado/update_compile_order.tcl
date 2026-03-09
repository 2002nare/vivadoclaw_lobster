# update_compile_order.tcl — Update compile order for sources_1 fileset
# Environment:
#   VIVADO_PROJECT_DIR — project directory containing .xpr
# Output (stdout): JSON with compile order status

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc main {} {
    set project_dir $::env(VIVADO_PROJECT_DIR)

    set xpr_files [glob -nocomplain -directory $project_dir *.xpr]
    if {[llength $xpr_files] == 0} {
        puts "{\"ok\": false, \"error\": \"No .xpr file found in $project_dir\"}"
        return
    }
    open_project [lindex $xpr_files 0]

    # Update compile order
    update_compile_order -fileset sources_1

    # Verify by getting compile order files
    set status "resolved"
    set file_count 0
    if {[catch {
        set files [get_files -compile_order sources -used_in synthesis -of_objects [get_filesets sources_1]]
        set file_count [llength $files]
    } err]} {
        set status "error"
    }

    close_project

    puts "{\"ok\": true, \"data\": {\"status\": [json_escape $status], \"file_count\": $file_count}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
