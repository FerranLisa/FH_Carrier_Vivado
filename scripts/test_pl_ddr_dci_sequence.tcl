set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
create_project -force test_dci [file join $root results dci_sim] -part xczu7ev-ffvc1156-2-i
add_files [file join $root FH_Carrier_Bringup.srcs sources_1 new pl_ddr_dci_reset.v]
add_files -fileset sim_1 [file join $root tests tb_pl_ddr_dci_sequence.sv]
set_property top tb_pl_ddr_dci_sequence [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
set fd [open [file join $root results dci_sim test_dci.sim sim_1 behav xsim simulate.log] r]
set log [read $fd];close $fd
if {![string match *PL_DDR_DCI_SEQUENCE_PASS* $log] || [string match *Fatal:* $log]} {error "DCI sequence regression failed"}
close_project
