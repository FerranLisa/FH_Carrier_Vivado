# Source from Hardware Manager after programming the matching BIT/LTX,
# starting the V16 application, and completing A, S, Y with stream still ON.
# Does not program hardware, change GPIO, reset the PS, or write sensor registers.
set cap_root [file dirname [file normalize [info script]]]
set cap_stamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
set cap_out [file join $cap_root captures $cap_stamp]
file mkdir $cap_out
set cap_dev [current_hw_device]
if {[llength $cap_dev] != 1} {error "Select the xczu7ev hardware device first"}
set cap_ilas {}
foreach cap_name {ila_rx_d0 ila_rx_d1 ila_rx_words} {
    set cap_ila [get_hw_ilas -quiet -of_objects $cap_dev -filter "CELL_NAME == $cap_name"]
    if {[llength $cap_ila] != 1} {error "Missing $cap_name: verify the matching BIT/LTX and refresh the device with sensor clocks ON"}
    lappend cap_ilas $cap_ila
    set_property CONTROL.DATA_DEPTH 2048 $cap_ila
    set_property CONTROL.TRIGGER_POSITION 1024 $cap_ila
    set_property CONTROL.WINDOW_COUNT 1 $cap_ila
    set_property CONTROL.CAPTURE_MODE ALWAYS $cap_ila
}
# Independent immediate acquisitions; there is no common trigger or cross-core
# time alignment. Each waveform must be interpreted in its own clock domain.
foreach cap_ila $cap_ilas {run_hw_ila -trigger_now $cap_ila}
foreach cap_ila $cap_ilas {
    wait_on_hw_ila -timeout 0.5 $cap_ila
    set cap_name [get_property CELL_NAME $cap_ila]
    set cap_data [upload_hw_ila_data $cap_ila]
    write_hw_ila_data -force [file join $cap_out ${cap_name}.ila] $cap_data
    write_hw_ila_data -force -csv_file [file join $cap_out ${cap_name}.csv] $cap_data
    display_hw_ila_data $cap_data
}
puts "Receiver ILA captures saved to $cap_out"
