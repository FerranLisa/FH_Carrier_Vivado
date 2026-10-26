set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
if {[get_property TOP [get_filesets sources_1]] ne "FH_Carrier_Bringup_top"} {error "Unexpected project top"}
# In-process full synthesis avoids dependence on Windows Script Host run launchers.
set bd [get_files */bd/design_1/design_1.bd]
set previous_mode [get_property SYNTH_CHECKPOINT_MODE $bd]
try {
    set_property SYNTH_CHECKPOINT_MODE None $bd
    generate_target all $bd
    update_compile_order -fileset sources_1
    synth_design -top FH_Carrier_Bringup_top -part xczu7ev-ffvc1156-2-i
    report_utilization -file [file join $root results gmax_project_utilization.rpt]
    report_drc -file [file join $root results gmax_project_drc.rpt]
    write_checkpoint -force [file join $root results gmax_project_synth.dcp]
} finally {
    set_property SYNTH_CHECKPOINT_MODE $previous_mode $bd
    close_project
}
