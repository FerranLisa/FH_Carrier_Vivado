# Run only after sync_v24_gui_results.ps1 verifies and imports completed outputs.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
set_property DESCRIPTION {v24 hardware-tested synthesis; restored from validated batch checkpoint} [get_runs synth_1]
set_property DESCRIPTION {v24 hardware-tested implementation/BIT; restored from validated batch results} [get_runs impl_1]
set_property NEEDS_REFRESH false [get_runs synth_1]
set_property NEEDS_REFRESH false [get_runs impl_1]
current_run -synthesis [get_runs synth_1]
current_run -implementation [get_runs impl_1]
close_project
open_project [file join $root FH_Carrier_Bringup.xpr]
foreach run {synth_1 impl_1} {
    puts "V24_GUI_RUN: $run STATUS=[get_property STATUS [get_runs $run]] PROGRESS=[get_property PROGRESS [get_runs $run]] NEEDS_REFRESH=[get_property NEEDS_REFRESH [get_runs $run]]"
}
open_run synth_1
if {[llength [get_cells -hier -filter {REF_NAME == DCIRESET}]] != 1} {error "GUI synthesis run is not corrected v24"}
close_design
open_run impl_1
if {[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]] < 0 || [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]] < 0} {error "GUI implementation timing failed"}
close_design
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {error "Synthesis status not complete"}
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {error "Implementation status not complete"}
close_project
puts "V24_GUI_RUNS_PASS"
