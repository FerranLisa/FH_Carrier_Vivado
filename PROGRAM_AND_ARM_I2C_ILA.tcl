# Program the current ZU7EV, configure the raw-I2C trigger and arm the ILA.
# Run from Vivado Hardware Manager after opening the hardware target.
# Vivado 2025.2

set proj [current_project]
if {$proj eq ""} { error "Open FH_Carrier_Bringup.xpr first" }
set proj_dir [get_property DIRECTORY $proj]
set run_dir [get_property DIRECTORY [get_runs impl_1]]
set bitfile [file join $run_dir design_1_wrapper.bit]
set ltxfile [file join $run_dir design_1_wrapper.ltx]

foreach artifact [list $bitfile $ltxfile] {
    if {![file exists $artifact] || [file size $artifact] == 0} {
        error "Missing or empty build artifact: $artifact"
    }
}

set dev [current_hw_device]
if {$dev eq ""} { error "Open the hardware target and select the ZU7EV device first" }

set_property PROGRAM.FILE $bitfile $dev
set_property PROBES.FILE $ltxfile $dev
program_hw_devices $dev
refresh_hw_device $dev

# Runtime names such as hw_ila_2 can change.  Select the core by its stable
# implemented cell name instead.
set raw_ilas {}
foreach ila [get_hw_ilas -of_objects $dev] {
    if {[get_property CELL_NAME $ila] eq "i2c_raw_ila"} {
        lappend raw_ilas $ila
    }
}
if {[llength $raw_ilas] != 1} {
    error "Expected exactly one i2c_raw_ila; found [llength $raw_ilas]: $raw_ilas"
}
set ila [lindex $raw_ilas 0]

proc fh_i2c_hw_probe {ila probe_name} {
    set matches [get_hw_probes -quiet -of_objects $ila $probe_name]
    if {[llength $matches] != 1} {
        error "Expected one I2C probe named $probe_name; found [llength $matches]: $matches"
    }
    return [lindex $matches 0]
}

# Clear any stale comparisons, then reproduce the verified START-condition
# setup used in Hardware Manager.  All enabled comparisons are ANDed.
foreach probe [get_hw_probes -of_objects $ila] {
    set_property TRIGGER_COMPARE_VALUE {eq1'bX} $probe
}
set_property TRIGGER_COMPARE_VALUE {eq1'b1} [fh_i2c_hw_probe $ila PAC1944_I2C_scl_i]
set_property TRIGGER_COMPARE_VALUE {eq1'b0} [fh_i2c_hw_probe $ila PAC1944_I2C_sda_i]
set_property TRIGGER_COMPARE_VALUE {eq1'b1} [fh_i2c_hw_probe $ila PAC1944_I2C_scl_t]
set_property TRIGGER_COMPARE_VALUE {eq1'b0} [fh_i2c_hw_probe $ila PAC1944_I2C_sda_t]
set_property CONTROL.TRIGGER_CONDITION AND $ila
set_property CONTROL.TRIGGER_POSITION 1024 $ila

run_hw_ila $ila

puts ""
puts "PAC1944 raw-I2C ILA programmed and armed."
puts "Core: $ila"
puts "Trigger: SCL_I=1 AND SDA_I=0 AND SCL_T=1 AND SDA_T=0"
puts "Trigger position: 1024 of 65536 samples"
puts "Run the PAC1944 test from Vitis now."
