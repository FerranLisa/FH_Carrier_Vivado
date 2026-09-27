set_property PACKAGE_PIN D2 [get_ports PAC1944_I2C_scl_io]
set_property PACKAGE_PIN C2 [get_ports PAC1944_I2C_sda_io]

set_property IOSTANDARD LVCMOS33 [get_ports PAC1944_I2C_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports PAC1944_I2C_sda_io]

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]

# PAC1944 I2C signals are asynchronous with respect to PL clock.
# They are observed by the ILA but are not synchronous PL interfaces.

set_false_path -from [get_ports {
    PAC1944_I2C_scl_io
    PAC1944_I2C_sda_io
}]
