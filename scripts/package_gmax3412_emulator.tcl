set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
set ipdir [file join $root ip gmax3412_emulator]
create_project -force package_gmax3412 [file join $root results emulator_package] -part xczu7ev-ffvc1156-2-i
add_files [glob [file join $ipdir hdl *.v]]
set_property top gmax3412_emulator [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir $ipdir -vendor fh.local -library user -taxonomy /UserIP -import_files -set_current true
set core [ipx::current_core]
set_property name gmax3412_emulator $core
set_property display_name {GMAX3412 emulator and frame checker} $core
set_property description {4096x3072 10-bit parallel Gpixel-style source, AXI4-Lite control, synchronous native commands, independent pixel checker.} $core
set_property version 1.0 $core
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
set axi [ipx::get_bus_interfaces s_axi -of_objects $core]
if {[llength $axi]!=1} { error "s_axi was not inferred" }
ipx::associate_bus_interfaces -busif s_axi -clock s_axi_aclk $core
foreach {name value} {PROTOCOL AXI4LITE DATA_WIDTH 32 ADDR_WIDTH 8 READ_WRITE_MODE READ_WRITE MAX_BURST_LENGTH 1 NUM_READ_OUTSTANDING 1 NUM_WRITE_OUTSTANDING 1} {
    set param [ipx::get_bus_parameters $name -of_objects $axi]
    if {![llength $param]} {set param [ipx::add_bus_parameter $name $axi]}
    set_property value $value $param
}
# Fixed geometry in the packaged milestone; HDL parameters enable fast unit tests.
foreach pname {IMAGE_WIDTH IMAGE_HEIGHT} {
    set p [ipx::get_user_parameters $pname -of_objects $core]
    set_property value_resolve_type immediate $p
    set_property enablement_value false $p
}
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
close_project
