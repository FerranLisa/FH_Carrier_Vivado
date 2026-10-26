set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
create_project -force test_ddr_reset [file join $root results ddr_reset_sim] -part xczu7ev-ffvc1156-2-i
foreach {name polarity} {reset_fixed 0 reset_old 0} {
    create_ip -name proc_sys_reset -vendor xilinx.com -library ip -version 5.0 -module_name $name
    set_property -dict [list CONFIG.C_EXT_RESET_HIGH 1 CONFIG.C_AUX_RESET_HIGH $polarity] [get_ips $name]
    generate_target simulation [get_ips $name]
}
add_files -fileset sim_1 [file join $root tests tb_pl_ddr_axi_reset.sv]
set_property top tb_pl_ddr_axi_reset [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
set fd [open [file join $root results ddr_reset_sim test_ddr_reset.sim sim_1 behav xsim simulate.log] r]
set log [read $fd];close $fd
if {![string match *PL_DDR_AXI_RESET_PASS* $log] || [string match *Fatal:* $log]} {error "DDR AXI reset regression failed"}
close_project
