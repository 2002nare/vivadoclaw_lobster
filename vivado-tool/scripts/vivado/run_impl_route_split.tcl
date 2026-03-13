# run_impl_route_split.tcl — Non-project implementation flow through route_design
# Environment:
#   VIVADO_PART           — FPGA part number
#   VIVADO_TOP_MODULE     — top module name
#   VIVADO_SOURCES_JSON   — JSON array of source file objects [{path,type,library?}]
#   VIVADO_CONSTRAINTS_JSON — JSON array of constraint file objects [{path}]
#   VIVADO_PROJECT_DIR    — base output directory
# Output: JSON with post-route checkpoint/report paths

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

proc add_sources_from_json {sources_json} {
    set objects [find_json_objects $sources_json]
    foreach obj $objects {
        set path [json_get $obj "path"]
        set type [json_get $obj "type"]
        if {$path eq ""} { continue }
        if {![file exists $path]} { error "Source file not found: $path" }
        switch -exact $type {
            "systemverilog" { read_verilog -sv $path }
            "vhdl"          { read_vhdl $path }
            default          { read_verilog $path }
        }
    }
}

proc add_constraints_from_json {constraints_json} {
    set objects [find_json_objects $constraints_json]
    foreach obj $objects {
        set path [json_get $obj "path"]
        if {$path eq ""} { continue }
        if {![file exists $path]} { error "Constraint file not found: $path" }
        read_xdc $path
    }
}

proc main {} {
    set part $::env(VIVADO_PART)
    set top $::env(VIVADO_TOP_MODULE)
    set project_dir $::env(VIVADO_PROJECT_DIR)

    set run_dir "$project_dir/impl_split"
    set chk_dir "$run_dir/checkpoints"
    set rpt_dir "$run_dir/reports"
    file mkdir $chk_dir
    file mkdir $rpt_dir

    add_sources_from_json $::env(VIVADO_SOURCES_JSON)
    add_constraints_from_json $::env(VIVADO_CONSTRAINTS_JSON)

    synth_design -top $top -part $part
    opt_design
    place_design
    route_design

    set dcp "$chk_dir/post_route.dcp"
    set timing_rpt "$rpt_dir/timing_post_route.rpt"
    set util_rpt "$rpt_dir/util_post_route.rpt"

    write_checkpoint -force $dcp
    report_timing_summary -file $timing_rpt
    report_utilization -file $util_rpt

    puts "{\"ok\": true, \"data\": {\"checkpoint\": [json_escape $dcp], \"timing_report\": [json_escape $timing_rpt], \"util_report\": [json_escape $util_rpt]}}"
}

if {[catch {main} err]} {
    set escaped [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t} $err]
    puts "{\"ok\": false, \"error\": \"$escaped\"}"
}
