# create_project.tcl — Create a new Vitis HLS project
# Environment:
#   VITIS_HLS_PROJECT_NAME — project name
#   VITIS_HLS_PROJECT_DIR  — parent directory to create project in
# Output (stdout): JSON with project directory path

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc main {} {
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set dir  $::env(VITIS_HLS_PROJECT_DIR)

    # Create parent directory if needed
    file mkdir $dir

    # Create project (-reset overwrites if exists)
    set proj_path "$dir/$name"
    open_project -reset $proj_path

    close_project

    puts "{\"ok\": true, \"data\": {\"project_dir\": [json_escape $proj_path]}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
