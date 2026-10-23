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
    inout  wire GMX_A_I2C_SDA,
    
    // ============================================================
    // GMAX3412-A Sub-LVDS data - 16 lanes
    // ============================================================

    input wire GMX_A_D0_P,
    input wire GMX_A_D0_N,
    input wire GMX_A_D1_P,
    input wire GMX_A_D1_N,
    input wire GMX_A_D2_P,
    input wire GMX_A_D2_N,
    input wire GMX_A_D3_P,
    input wire GMX_A_D3_N,
    input wire GMX_A_D4_P,
    input wire GMX_A_D4_N,
    input wire GMX_A_D5_P,
    input wire GMX_A_D5_N,
    input wire GMX_A_D6_P,
    input wire GMX_A_D6_N,
    input wire GMX_A_D7_P,
    input wire GMX_A_D7_N,
    input wire GMX_A_D8_P,
    input wire GMX_A_D8_N,
    input wire GMX_A_D9_P,
    input wire GMX_A_D9_N,
    input wire GMX_A_D10_P,
    input wire GMX_A_D10_N,
    input wire GMX_A_D11_P,
    input wire GMX_A_D11_N,
    input wire GMX_A_D12_P,
    input wire GMX_A_D12_N,
    input wire GMX_A_D13_P,
    input wire GMX_A_D13_N,
    input wire GMX_A_D14_P,
    input wire GMX_A_D14_N,
    input wire GMX_A_D15_P,
    input wire GMX_A_D15_N,
    
    // ============================================================
    // GMAX3412-A Sub-LVDS clocks
    // ============================================================

    input wire GMX_A_CLK0_P,
    input wire GMX_A_CLK0_N,
    input wire GMX_A_CLK1_P,
    input wire GMX_A_CLK1_N
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
    // bit 12:9 = V16 debug candidate index (0..13)
    // bit 13 = V16 debug lane select (0=D0, 1=D1)
    // bit 14 = V16 debug snapshot freeze
    //
    // Channel 2, input:
    //
    // bit 0      = GMX_A_SDO_TDIG
    // bits 16:1  = training_result[15:0]
    // bit 17     = training_done
    // bits 27:18 = selected D0/D1 candidate word[9:0]
    // bit 28     = candidate word valid
    // bit 29     = CLK_OUT0 activity seen
    // bit 30     = CLK_OUT1 activity seen
    // bit 31     = selected lane raw ISERDES activity seen
    // ============================================================

    wire [14:0] gmax_a_ctrl;
    wire [31:0] gmax_a_status;


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

    assign gmax_a_status[0]     = GMX_A_SDO_TDIG;
    assign gmax_a_status[16:1]  = gmax_a_training_result;
    assign gmax_a_status[17]    = gmax_a_training_done;
    assign gmax_a_status[27:18] = gmax_a_debug_word;
    assign gmax_a_status[28]    = gmax_a_debug_word_valid;
    assign gmax_a_status[29]    = gmax_a_debug_clk0_activity;
    assign gmax_a_status[30]    = gmax_a_debug_clk1_activity;
    assign gmax_a_status[31]    = gmax_a_debug_lane_activity;
    
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

    // ============================================================
    // GMAX3412-A Sub-LVDS data
    // ============================================================

    wire [15:0] gmax_a_data_p;
    wire [15:0] gmax_a_data_n;
    
    assign gmax_a_data_p = {
        GMX_A_D15_P, GMX_A_D14_P, GMX_A_D13_P, GMX_A_D12_P,
        GMX_A_D11_P, GMX_A_D10_P, GMX_A_D9_P,  GMX_A_D8_P,
        GMX_A_D7_P,  GMX_A_D6_P,  GMX_A_D5_P,  GMX_A_D4_P,
        GMX_A_D3_P,  GMX_A_D2_P,  GMX_A_D1_P,  GMX_A_D0_P
    };
    
    assign gmax_a_data_n = {
        GMX_A_D15_N, GMX_A_D14_N, GMX_A_D13_N, GMX_A_D12_N,
        GMX_A_D11_N, GMX_A_D10_N, GMX_A_D9_N,  GMX_A_D8_N,
        GMX_A_D7_N,  GMX_A_D6_N,  GMX_A_D5_N,  GMX_A_D4_N,
        GMX_A_D3_N,  GMX_A_D2_N,  GMX_A_D1_N,  GMX_A_D0_N
    };
    
    // ============================================================
    // GMAX3412-A Sub-LVDS 16-lane training adapter
    // ============================================================

    // Keep the receiver observability/status nets through synthesis so the
    // 16-lane RX cannot be optimized away while the AXI/BIST status block
    // is not yet connected.  These are temporary bring-up attributes.
    wire [15:0] gmax_a_training_result;
    wire        gmax_a_training_done;
    wire        gmax_a_pixel_clk;
    wire        gmax_a_frame_valid;
    wire        gmax_a_line_valid;
    wire [191:0] gmax_a_image_data;
    wire [9:0]  gmax_a_debug_word;
    wire        gmax_a_debug_word_valid;
    wire        gmax_a_debug_clk0_activity;
    wire        gmax_a_debug_clk1_activity;
    wire        gmax_a_debug_lane_activity;

    // Temporary bring-up protection: force Vivado to elaborate and retain
    // the complete GMAX RX hierarchy so genuine primitive/RTL compatibility
    // errors are visible instead of being hidden by optimization.
    gmax3412_rx_adapter u_gmax_a_rx
    (
        .rst_n           (GMX_A_SYS_RST_N),
    
        .clk0_p          (GMX_A_CLK0_P),
        .clk0_n          (GMX_A_CLK0_N),
        .clk1_p          (GMX_A_CLK1_P),
        .clk1_n          (GMX_A_CLK1_N),
    
        .data_p          (gmax_a_data_p),
        .data_n          (gmax_a_data_n),

        .debug_word_index  (gmax_a_ctrl[12:9]),
        .debug_lane_select (gmax_a_ctrl[13]),
        .debug_freeze      (gmax_a_ctrl[14]),
    
        .training_result (gmax_a_training_result),
        .training_done   (gmax_a_training_done),

        .debug_word         (gmax_a_debug_word),
        .debug_word_valid   (gmax_a_debug_word_valid),
        .debug_clk0_activity(gmax_a_debug_clk0_activity),
        .debug_clk1_activity(gmax_a_debug_clk1_activity),
        .debug_lane_activity(gmax_a_debug_lane_activity),
    
        .pixel_clk       (gmax_a_pixel_clk),
        .frame_valid     (gmax_a_frame_valid),
        .line_valid      (gmax_a_line_valid),
        .image_data      (gmax_a_image_data)
    );
            


endmodule
