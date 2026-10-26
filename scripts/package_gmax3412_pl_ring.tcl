set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
set ipdir [file join $root ip gmax3412_pl_ring]
create_project -force package_pl_ring [file join $root results pl_ring_package] -part xczu7ev-ffvc1156-2-i
add_files [glob [file join $ipdir hdl *.v]]
set_property top gmax3412_pl_ring [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir $ipdir -vendor fh.local -library user -taxonomy /UserIP -import_files -set_current true
set core [ipx::current_core]
set_property name gmax3412_pl_ring $core
set_property version 1.0 $core
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
set axi [ipx::get_bus_interfaces m_axi -of_objects $core]
if {[llength $axi]!=1} {error "Master interface missing"}
ipx::associate_bus_interfaces -busif m_axi -clock clk $core
foreach {name value} {PROTOCOL AXI4LITE DATA_WIDTH 32 ADDR_WIDTH 32 READ_WRITE_MODE READ_WRITE MAX_BURST_LENGTH 1 NUM_READ_OUTSTANDING 1 NUM_WRITE_OUTSTANDING 1} {
 set param [ipx::get_bus_parameters $name -of_objects $axi]
 if {![llength $param]} {set param [ipx::add_bus_parameter $name $axi]}
 set_property value $value $param
}
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
close_project
