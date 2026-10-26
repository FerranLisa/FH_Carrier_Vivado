set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
create_project -force test_scheduler [file join $root results scheduler_sim] -part xczu7ev-ffvc1156-2-i
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO} [current_project]
add_files [file join $root ip gmax3412_scheduler hdl gmax3412_scheduler.v]
add_files [glob [file join $root ip gmax3412_capture hdl *.v]]
add_files [file join $root ip gmax3412_emulator hdl gmax3412_pattern.v]
add_files [file join $root ip gmax3412_emulator hdl gmax3412_checker.v]
add_files -fileset sim_1 [file join $root tests tb_gmax3412_scheduler.sv]
set_property top tb_gmax3412_scheduler [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
set fd [open [file join $root results scheduler_sim test_scheduler.sim sim_1 behav xsim simulate.log] r]
set log [read $fd];close $fd
if {![string match *SCHEDULER_TEST_PASS* $log] || [string match *Fatal:* $log]} {error "Scheduler regression failed"}
close_project
