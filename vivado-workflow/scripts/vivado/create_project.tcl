# create_project.tcl — Create a new Vivado project
# Environment:
#   VIVADO_PROJECT_NAME — project name
#   VIVADO_PART         — FPGA part number (e.g., xc7a35tcpg236-1)
#   VIVADO_PROJECT_DIR  — directory to create project in
# Output (stdout): JSON with xpr path

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc main {} {
    set name $::env(VIVADO_PROJECT_NAME)
    set part $::env(VIVADO_PART)
    set dir  $::env(VIVADO_PROJECT_DIR)

    # Create project directory if needed
    file mkdir $dir

    # Create project (-force overwrites if exists)
    create_project -force $name $dir -part $part

    set xpr_path [get_property DIRECTORY [current_project]]/${name}.xpr

    close_project

    puts "{\"ok\": true, \"data\": {\"xpr_path\": [json_escape $xpr_path]}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
