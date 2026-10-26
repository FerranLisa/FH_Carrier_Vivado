# Run from a fresh Vivado 2025.2 batch session:
# vivado -mode batch -source REBUILD_V16_3.tcl
# Optional full reset (including generated IP synthesis runs): -tclargs full
set root [file dirname [file normalize [info script]]]
if {$tcl_platform(platform) eq "windows" && [string length $root] > 70} {
    error "Extract the project to a short path (for example C:/Projects/FH_V16_3) or use a subst drive before rebuilding; debug-core generation has a Windows path limit."
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
update_compile_order -fileset sources_1
set stamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
set out [file join $root results $stamp]
file mkdir $out
report_compile_order -used_in synthesis -file $out/compile_order.rpt
report_compile_order -constraints -file $out/constraint_order.rpt
set adapters {}
foreach f [get_files -compile_order sources -used_in synthesis] {
    if {[file extension $f] ni {.v .sv}} {continue}
    set h [open $f r]; set txt [read $h]; close $h
    if {[regexp {module\s+gmax3412_rx_adapter\M} $txt]} {lappend adapters $f}
}
if {[llength $adapters] != 1} {error "Expected exactly one compiled adapter: $adapters"}
proc verify_freeze {out stage} {
    set xpm [get_cells -quiet -hier -regexp {.*u_xpm_cdc_debug_freeze/syncstages_ff_reg\[[01]\]}]
    set old [get_cells -quiet -hier -regexp {.*debug_freeze_sync_reg.*}]
    set h [open $out/${stage}_identity.txt w]
    puts $h "XPM stages: $xpm\nOld synchronizer: $old"; close $h
    if {[llength $xpm] != 2 || [llength $old] != 0} {error "V16.3 netlist identity check failed in $stage"}
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
report_clocks -file $out/clocks.rpt
report_cdc -details -file $out/cdc.rpt
report_methodology -file $out/methodology.rpt
report_drc -file $out/drc.rpt
report_bus_skew -file $out/bus_skew.rpt
report_clock_interaction -file $out/clock_interaction.rpt
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
    error "Timing summary did not confirm setup, hold and pulse-width closure; inspect $out"
}
set h [open $out/bus_skew.rpt r]; set skew_text [read $h]; close $h
if {[regexp {Slack \(VIOLATED\)} $skew_text]} {error "Bus skew failed; inspect $out"}
puts "BUILD REPORTS: $out"
puts "Review CDC, bus skew, pulse width, DRC and hardware training before releasing a bitstream."
close_project
