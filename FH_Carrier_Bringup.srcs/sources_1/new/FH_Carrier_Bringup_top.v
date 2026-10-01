`timescale 1 ps / 1 ps

module FH_Carrier_Bringup_top
(
    // ============================================================
    // Existing FH_Carrier interfaces
    // ============================================================

    input  wire M2_PCIE_REFCLK_SOM_N_0,
    input  wire M2_PCIE_REFCLK_SOM_P_0,

    inout  wire PAC1944_I2C_scl_io,
    inout  wire PAC1944_I2C_sda_io,

    // ============================================================
    // FH_Sen4K / GMAX3412 A control
    // ZU7EV Bank 28, VCCO confirmed = 1.8 V
    // ============================================================

    output wire GMX_A_PWR_EN,
    output wire GMX_A_CLK_EN,
    output wire GMX_A_SYS_RST_N,
    output wire GMX_A_CCI_EN,
    output wire GMX_A_XCE_SLAMODE,

    output wire GMX_A_TEXP1,
    output wire GMX_A_TEXP2,

    output wire GMX_A_SPI_SCK,
    output wire GMX_A_SPI_SDI,
    input  wire GMX_A_SDO_TDIG,

    inout  wire GMX_A_I2C_SCL,
    inout  wire GMX_A_I2C_SDA
);


    // ============================================================
    // AXI GPIO internal vectors
    //
    // Channel 1, output:
    //
    // bit 0 = GMX_A_PWR_EN
    // bit 1 = GMX_A_CLK_EN
    // bit 2 = GMX_A_SYS_RST_N
    // bit 3 = GMX_A_CCI_EN
    // bit 4 = GMX_A_XCE_SLAMODE
    // bit 5 = GMX_A_TEXP1
    // bit 6 = GMX_A_TEXP2
    // bit 7 = GMX_A_SPI_SCK
    // bit 8 = GMX_A_SPI_SDI
    //
    // Channel 2, input:
    //
    // bit 0 = GMX_A_SDO_TDIG
    // ============================================================

    wire [8:0] gmax_a_ctrl;
    wire [0:0] gmax_a_status;


    // ============================================================
    // GPIO outputs -> FH_Sen4K
    // ============================================================

    assign GMX_A_PWR_EN      = gmax_a_ctrl[0];
    assign GMX_A_CLK_EN      = gmax_a_ctrl[1];
    assign GMX_A_SYS_RST_N   = gmax_a_ctrl[2];
    assign GMX_A_CCI_EN      = gmax_a_ctrl[3];
    assign GMX_A_XCE_SLAMODE = gmax_a_ctrl[4];

    assign GMX_A_TEXP1       = gmax_a_ctrl[5];
    assign GMX_A_TEXP2       = gmax_a_ctrl[6];

    assign GMX_A_SPI_SCK     = gmax_a_ctrl[7];
    assign GMX_A_SPI_SDI     = gmax_a_ctrl[8];


    // ============================================================
    // FH_Sen4K input -> GPIO status channel
    // ============================================================

    assign gmax_a_status[0] = GMX_A_SDO_TDIG;


    // ============================================================
    // Vivado generated Block Design wrapper
    //
    // Important:
    // design_1_wrapper already contains the IOBUFs for
    // GMX_A_I2C_SCL and GMX_A_I2C_SDA.
    // ============================================================

    design_1_wrapper u_design_1_wrapper
    (
        .GMX_A_CTRL_tri_o         (gmax_a_ctrl),

        .GMX_A_I2C_scl_io         (GMX_A_I2C_SCL),
        .GMX_A_I2C_sda_io         (GMX_A_I2C_SDA),

        .GMX_A_STATUS_tri_i       (gmax_a_status),

        .M2_PCIE_REFCLK_SOM_N_0   (M2_PCIE_REFCLK_SOM_N_0),
        .M2_PCIE_REFCLK_SOM_P_0   (M2_PCIE_REFCLK_SOM_P_0),

        .PAC1944_I2C_scl_io       (PAC1944_I2C_scl_io),
        .PAC1944_I2C_sda_io       (PAC1944_I2C_sda_io)
    );

endmodule
