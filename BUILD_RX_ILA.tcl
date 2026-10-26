# Vivado 2025.2 batch: vivado -mode batch -source BUILD_RX_ILA.tcl
# Optional -tclargs full resets all generated-IP synthesis runs as well.
set root [file dirname [file normalize [info script]]]
if {$tcl_platform(platform) eq "windows" && [string length $root] > 70} {
    error "Use a short extraction path, e.g. C:/Projects/FH_RX_ILA; Windows debug-core generation has a path limit."
}
cd $root
if {![string match "2025.2*" [version -short]]} {error "Use Vivado 2025.2"}
open_project FH_Carrier_Bringup.xpr
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
set impl_xdc [get_files */FH_Carrier_Bringup_impl.xdc]
set_property USED_IN_SYNTHESIS false $impl_xdc
set_property USED_IN_IMPLEMENTATION true $impl_xdc
set_property PROCESSING_ORDER LATE $impl_xdc
foreach r {synth_1 impl_1} {
    set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $r]
    set_property INCREMENTAL_CHECKPOINT {} [get_runs $r]
}
set hook [file join $root insert_receiver_ila.tcl]
if {[llength [get_files -quiet $hook]] == 0} {add_files -fileset utils_1 -norecurse $hook}
set_property STEPS.INIT_DESIGN.TCL.POST $hook [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED false [get_runs impl_1]
update_compile_order -fileset sources_1
set stamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
set out [file join $root results $stamp]
file mkdir $out
file mkdir debug
file delete -force debug/BUILD_COMPLETE.txt
report_compile_order -used_in synthesis -file $out/compile_order.rpt
report_compile_order -constraints -file $out/constraint_order.rpt
proc verify_freeze {out stage} {
    set xpm [get_cells -quiet -hier -regexp {.*u_xpm_cdc_debug_freeze/syncstages_ff_reg\[[01]\]}]
    set old [get_cells -quiet -hier -regexp {.*debug_freeze_sync_reg.*}]
    set h [open $out/${stage}_identity.txt w]
    puts $h "XPM stages: $xpm\nOld synchronizer: $old"; close $h
    if {[llength $xpm] != 2 || [llength $old] != 0} {error "V16.3 netlist identity failed in $stage"}
}
reset_run impl_1
reset_run synth_1
if {[llength $argv] && [lindex $argv 0] eq "full"} {
    foreach r [get_runs -filter {IS_SYNTHESIS && NAME != synth_1}] {reset_run $r}
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
open_run synth_1
verify_freeze $out synth
close_design
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
verify_freeze $out routed
source verify_constraints.tcl
foreach c {ila_rx_d0 ila_rx_d1 ila_rx_words} {
    if {[llength [get_debug_cores -quiet $c]] != 1} {error "Receiver ILA missing: $c"}
}
report_clocks -file $out/clocks.rpt
report_cdc -details -file $out/cdc.rpt
report_methodology -file $out/methodology.rpt
report_drc -file $out/drc.rpt
report_bus_skew -file $out/bus_skew.rpt
report_clock_interaction -file $out/clock_interaction.rpt
report_utilization -file $out/utilization.rpt
check_timing -verbose -file $out/check_timing.rpt
report_timing_summary -report_unconstrained -max_paths 10 -file $out/timing.rpt -rpx $out/timing.rpx
write_checkpoint -force $out/routed.dcp
write_xdc -force $out/effective.xdc
set setup [get_timing_paths -delay_type max -max_paths 1]
set hold [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup] == 0 || [llength $hold] == 0} {error "Timing paths missing"}
if {[get_property SLACK $setup] < 0 || [get_property SLACK $hold] < 0} {error "Timing failed; inspect $out"}
set h [open $out/timing.rpt r]; set timing_text [read $h]; close $h
if {[string first "All user specified timing constraints are met." $timing_text] < 0} {
    error "Setup, hold or pulse-width closure failed; inspect $out"
}
set h [open $out/bus_skew.rpt r]; set skew_text [read $h]; close $h
if {[regexp {Slack \(VIOLATED\)} $skew_text]} {error "Bus skew failed; inspect $out"}
set bad_drc [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == "Critical Warning"}]
if {[llength $bad_drc]} {error "DRC errors/critical warnings: $bad_drc"}
set completion_text "Vivado: [version -short]\nReports: $out\nSetup WNS: [get_property SLACK $setup] ns\nHold WHS: [get_property SLACK $hold] ns"
# Finish the project run so XSA export finds the official run bitstream.
# No post-route optimization may occur after the accepted timing reports.
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    error "Bitstream run did not complete: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
write_debug_probes -force debug/FH_Carrier_Bringup_RX_ILA.ltx
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] FH_Carrier_Bringup_top.bit] debug/FH_Carrier_Bringup_RX_ILA.bit
write_hw_platform -fixed -include_bit -force -file debug/FH_Carrier_Bringup_RX_ILA.xsa
set h [open debug/BUILD_COMPLETE.txt w]
puts $h $completion_text
puts $h "BIT/LTX/XSA generated from this routed design. CDC findings remain for review; this is a diagnostic build."
close $h
puts "RX ILA BUILD COMPLETE. Reports: $out ; programming pair: debug/FH_Carrier_Bringup_RX_ILA.bit + .ltx"
close_project
