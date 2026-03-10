# create_solution.tcl — Create solution with part and clock for Vitis HLS project
# Environment:
#   VITIS_HLS_PROJECT_DIR   — parent directory containing project
#   VITIS_HLS_PROJECT_NAME  — project name
#   VITIS_HLS_SOLUTION_NAME — solution name (default: solution1)
#   VITIS_HLS_PART          — FPGA part number (e.g., xc7a35tcpg236-1)
#   VITIS_HLS_CLOCK_PERIOD  — clock period in ns (e.g., 10)
# Output (stdout): JSON with solution info

proc json_escape {s} {
    set s [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $s]
    return "\"$s\""
}

proc main {} {
    set project_dir $::env(VITIS_HLS_PROJECT_DIR)
    set name $::env(VITIS_HLS_PROJECT_NAME)
    set solution_name $::env(VITIS_HLS_SOLUTION_NAME)
    set part $::env(VITIS_HLS_PART)
    set clock_period $::env(VITIS_HLS_CLOCK_PERIOD)

    open_project "$project_dir/$name"

    # Create or reset solution
    open_solution -reset $solution_name

    # Set target part
    set_part $part

    # Set clock constraint
    create_clock -period $clock_period

    close_solution
    close_project

    puts "{\"ok\": true, \"data\": {\"solution\": [json_escape $solution_name], \"part\": [json_escape $part], \"clock_period_ns\": [json_escape $clock_period]}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
