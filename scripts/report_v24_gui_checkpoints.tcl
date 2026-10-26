# Regenerate GUI-readable reports from the exact saved v24 checkpoints.
# This does not synthesize, place, route or regenerate the tested BIT.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
set stem [file join $root exports gmax3412_pl_ddr FH_Carrier_Bringup_GMAX3412_PL_DDR]
set top FH_Carrier_Bringup_top
set syn [file join $root FH_Carrier_Bringup.runs synth_1]
set impl [file join $root FH_Carrier_Bringup.runs impl_1]
open_checkpoint ${stem}_synth.dcp
if {[llength [get_cells -hier -filter {REF_NAME == DCIRESET}]] != 1} {error "DCI primitive missing from synthesis checkpoint"}
report_utilization -file [file join $syn ${top}_utilization_synth.rpt] -pb [file join $syn ${top}_utilization_synth.pb]
close_design
open_checkpoint ${stem}_routed.dcp
if {[llength [get_cells -hier -filter {REF_NAME == DCIRESET}]] != 1} {error "DCI primitive missing from routed checkpoint"}
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
if {$wns < 0 || $whs < 0} {error "Routed checkpoint fails timing"}
report_timing_summary -report_unconstrained -file [file join $impl ${top}_timing_summary_routed.rpt] -pb [file join $impl ${top}_timing_summary_routed.pb] -rpx [file join $impl ${top}_timing_summary_routed.rpx]
report_utilization -file [file join $impl ${top}_utilization_placed.rpt] -pb [file join $impl ${top}_utilization_placed.pb]
report_route_status -file [file join $impl ${top}_route_status.rpt] -pb [file join $impl ${top}_route_status.pb]
report_drc -file [file join $impl ${top}_drc_routed.rpt] -pb [file join $impl ${top}_drc_routed.pb] -rpx [file join $impl ${top}_drc_routed.rpx]
report_methodology -file [file join $impl ${top}_methodology_drc_routed.rpt] -pb [file join $impl ${top}_methodology_drc_routed.pb] -rpx [file join $impl ${top}_methodology_drc_routed.rpx]
report_bus_skew -file [file join $impl ${top}_bus_skew_routed.rpt] -pb [file join $impl ${top}_bus_skew_routed.pb] -rpx [file join $impl ${top}_bus_skew_routed.rpx]
close_design
puts "V24_GUI_CHECKPOINT_REPORTS_PASS: WNS=$wns WHS=$whs"
