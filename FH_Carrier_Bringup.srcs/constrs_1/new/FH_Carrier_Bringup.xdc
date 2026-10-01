# ============================================================
# PAC1944 Power Monitor I2C
# PS I2C1 through EMIO
# ============================================================

set_property PACKAGE_PIN D2 [get_ports PAC1944_I2C_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports PAC1944_I2C_scl_io]

set_property PACKAGE_PIN C2 [get_ports PAC1944_I2C_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports PAC1944_I2C_sda_io]

set_property PULLTYPE NONE [get_ports PAC1944_I2C_scl_io]
set_property PULLTYPE NONE [get_ports PAC1944_I2C_sda_io]

# ============================================================
# FH_Sen4K / GMAX3412 A
# ZU7EV BANK 28
# VCCO experimentally confirmed = 1.8 V
# ============================================================

# Power / clock / reset / interface selection

set_property PACKAGE_PIN A19 [get_ports GMX_A_PWR_EN]
set_property PACKAGE_PIN A18 [get_ports GMX_A_CLK_EN]
set_property PACKAGE_PIN A21 [get_ports GMX_A_SYS_RST_N]
set_property PACKAGE_PIN A20 [get_ports GMX_A_CCI_EN]

# XCE in SPI mode / SLAMODE in I2C mode

set_property PACKAGE_PIN L22 [get_ports GMX_A_XCE_SLAMODE]

# Exposure

set_property PACKAGE_PIN L23 [get_ports GMX_A_TEXP1]
set_property PACKAGE_PIN K24 [get_ports GMX_A_TEXP2]

# SPI

set_property PACKAGE_PIN C18 [get_ports GMX_A_SPI_SCK]
set_property PACKAGE_PIN C19 [get_ports GMX_A_SPI_SDI]
set_property PACKAGE_PIN L21 [get_ports GMX_A_SDO_TDIG]

# I2C

set_property PACKAGE_PIN J21 [get_ports GMX_A_I2C_SCL]
set_property PACKAGE_PIN J22 [get_ports GMX_A_I2C_SDA]

# All GMAX_A control I/O is Bank 28 / 1.8 V

set_property IOSTANDARD LVCMOS18 [get_ports {
    GMX_A_PWR_EN
    GMX_A_CLK_EN
    GMX_A_SYS_RST_N
    GMX_A_CCI_EN
    GMX_A_XCE_SLAMODE
    GMX_A_TEXP1
    GMX_A_TEXP2
    GMX_A_SPI_SCK
    GMX_A_SPI_SDI
    GMX_A_SDO_TDIG
    GMX_A_I2C_SCL
    GMX_A_I2C_SDA
}]