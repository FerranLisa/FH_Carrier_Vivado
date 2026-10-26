set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
create_project -force test_timing [file join $root results timing_sim] -part xczu7ev-ffvc1156-2-i
add_files [glob [file join $root ip gmax3412_emulator hdl *.v]]
add_files -fileset sim_1 [file join $root tests tb_gmax3412_timing.sv]
set_property top tb_gmax3412_timing [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
set fd [open [file join $root results timing_sim test_timing.sim sim_1 behav xsim simulate.log] r]
set log [read $fd];close $fd
if {![string match *TIMING_TEST_PASS* $log] || [string match *Fatal:* $log]} {error "Timing regression failed"}
close_project
