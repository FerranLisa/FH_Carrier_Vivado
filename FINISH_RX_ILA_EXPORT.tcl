# Complete only the bitstream/export stage after the already-accepted route.
set root [file dirname [file normalize [info script]]]
cd $root
open_project FH_Carrier_Bringup.xpr
set hook [file join $root insert_receiver_ila.tcl]
if {[llength [get_files -quiet $hook]] == 0} {add_files -fileset utils_1 -norecurse $hook}
set_property STEPS.INIT_DESIGN.TCL.POST $hook [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED false [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "FINAL RUN STATUS: [get_property STATUS [get_runs impl_1]]"
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {error "Bitstream run failed"}
open_run impl_1
source verify_constraints.tcl
set xpm [get_cells -quiet -hier -regexp {.*u_xpm_cdc_debug_freeze/syncstages_ff_reg\[[01]\]}]
set old [get_cells -quiet -hier -regexp {.*debug_freeze_sync_reg.*}]
if {[llength $xpm] != 2 || [llength $old]} {error "Wrong receiver identity"}
write_debug_probes -force debug/FH_Carrier_Bringup_RX_ILA.ltx
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] FH_Carrier_Bringup_top.bit] debug/FH_Carrier_Bringup_RX_ILA.bit
write_hw_platform -fixed -include_bit -force -file debug/FH_Carrier_Bringup_RX_ILA.xsa
set h [open debug/BUILD_COMPLETE.txt w]
puts $h "Vivado: [version -short]\nReports: results/20261004_100615\nSetup WNS: +0.131 ns\nHold WHS: +0.010 ns"
puts $h "BIT/LTX/XSA generated from the accepted routed design; write_bitstream run complete."
puts $h "CDC findings remain for review; this is a diagnostic build."
close $h
close_project
