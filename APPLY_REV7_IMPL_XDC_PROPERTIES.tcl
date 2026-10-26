# Run once after adding FH_Carrier_Bringup_impl.xdc to the project constraints set.
set impl_xdc [get_files -all *FH_Carrier_Bringup_impl.xdc]
if {[llength $impl_xdc] != 1} {
    error "Expected exactly one FH_Carrier_Bringup_impl.xdc in the project"
}
set_property USED_IN_SYNTHESIS false $impl_xdc
set_property USED_IN_IMPLEMENTATION true $impl_xdc
set_property PROCESSING_ORDER LATE $impl_xdc
puts "Configured implementation-only constraints: $impl_xdc"
