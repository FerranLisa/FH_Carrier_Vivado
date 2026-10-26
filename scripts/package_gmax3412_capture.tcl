set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
set ipdir [file join $root ip gmax3412_capture]
create_project -force package_capture [file join $root results capture_package] -part xczu7ev-ffvc1156-2-i
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO} [current_project]
add_files [glob [file join $ipdir hdl *.v]]
set_property top gmax3412_capture [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir $ipdir -vendor fh.local -library user -taxonomy /UserIP -import_files -set_current true
set core [ipx::current_core]
set_property name gmax3412_capture $core
set_property display_name {GMAX3412 selectable frame capture bridge} $core
set_property version 1.0 $core
ipx::infer_bus_interfaces xilinx.com:interface:axis_rtl:1.0 $core
ipx::associate_bus_interfaces -busif m_axis -clock clk $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
close_project
