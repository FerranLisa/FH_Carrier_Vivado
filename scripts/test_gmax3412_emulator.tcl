set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
create_project -force test_gmax3412 [file join $root results emulator_sim] -part xczu7ev-ffvc1156-2-i
add_files [glob [file join $root ip gmax3412_emulator hdl *.v]]
add_files -fileset sim_1 [file join $root tests tb_gmax3412_emulator.sv]
set_property top tb_gmax3412_emulator [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
set logpath [file join $root results emulator_sim test_gmax3412.sim sim_1 behav xsim simulate.log]
set fd [open $logpath r]
set simlog [read $fd]
close $fd
if {![string match "*PASS: full 4096x3072 frame*" $simlog] || [string match "*Fatal:*" $simlog]} {
    error "Emulator regression did not pass; inspect $logpath"
}
close_project
