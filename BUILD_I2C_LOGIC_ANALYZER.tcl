# One-command clean build for Vivado 2025.2. Run with the project open.
set proj [current_project]
if {$proj eq ""} { error "Open FH_Carrier_Bringup.xpr first" }
set proj_dir [get_property DIRECTORY $proj]
source [file join $proj_dir SETUP_I2C_LOGIC_ANALYZER.tcl]
# SETUP regenerates BD targets, exports IP files, updates compile order,
# installs the preserved raw-I2C hook, then resets OOC/top-level runs.
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    ![string match "*synth_design Complete*" [get_property STATUS [get_runs synth_1]]]} {
    error "Synthesis failed or incomplete: [get_property STATUS [get_runs synth_1]]"
}
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%" ||
    ![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "Bitstream generation failed or incomplete: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
puts "Debug cores in implemented design:"
puts [get_debug_cores]
set run_dir [get_property DIRECTORY [get_runs impl_1]]
set bitfile [file join $run_dir design_1_wrapper.bit]
set ltxfile [file join $run_dir design_1_wrapper.ltx]
if {[llength [get_debug_cores -quiet i2c_raw_ila]] != 1} {
    error "Implemented design is missing i2c_raw_ila"
}
if {[llength [get_debug_cores -quiet *system_ila*]] == 0} {
    error "Implemented design is missing the existing System ILA"
}
set pwrdn_port [get_ports -quiet VMON_PWRDN]
if {[llength $pwrdn_port] != 1} {
    error "Implemented design is missing the VMON_PWRDN output"
}
if {[get_property LOC $pwrdn_port] ne "E5"} {
    error "VMON_PWRDN is not assigned to package pin E5"
}
if {[get_property IOSTANDARD $pwrdn_port] ne "LVCMOS33"} {
    error "VMON_PWRDN is not configured as LVCMOS33"
}
# Export probes from this implemented design, never a previous build.
write_debug_probes -force $ltxfile
foreach artifact [list $bitfile $ltxfile] {
    if {![file exists $artifact] || [file size $artifact] == 0} {
        error "Missing or empty build artifact: $artifact"
    }
}
puts "BIT: $bitfile"
puts "LTX: $ltxfile"
puts "Expected debug core: i2c_raw_ila"
puts "Probe map: p0=SCL_I p1=SDA_I p2=SCL_O p3=SCL_T p4=SDA_O p5=SDA_T"
puts "PAC1944 enable: VMON_PWRDN driven high on E5"
puts "To program, load the verified trigger and arm the ILA:"
puts "  source [file join $proj_dir PROGRAM_AND_ARM_I2C_ILA.tcl]"

