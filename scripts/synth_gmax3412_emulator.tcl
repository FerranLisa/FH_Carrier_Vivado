set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
read_verilog [glob [file join $root ip gmax3412_emulator hdl *.v]]
synth_design -top gmax3412_emulator -part xczu7ev-ffvc1156-2-i -mode out_of_context
create_clock -period 8.333333 [get_ports s_axi_aclk]
opt_design
place_design
route_design
report_utilization -file [file join $root results gmax_emulator_utilization.rpt]
report_timing_summary -file [file join $root results gmax_emulator_timing.rpt]
report_drc -file [file join $root results gmax_emulator_drc.rpt]
if {[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]] < 0} {error "Emulator fails 120 MHz timing"}
write_checkpoint -force [file join $root results gmax_emulator_routed.dcp]
