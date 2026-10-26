`timescale 1ns / 1ps
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// --Function  : GMAX3412 DDR clock module
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// --History   :
// --Ver       Date         By              Description
// --1.0       2023.09.11   LTJ             create
// --FH-1      2026.10.02   OpenAI          Remove obsolete CCIO_EN_* IBUFDS parameters for ZU7EV/Vivado 2025.2.
// --FH-2      2026.10.02   OpenAI          Add 600 MHz -> 120 MHz (/5) word clock for GMAX3412 10-bit @1.20 Gb/s.
// --FH-3      2026.10.02   OpenAI          Safe clock startup: all BUFGCE_DIVs use common active-low reset_n on CLR;
//                                           add per-domain async-assert/sync-deassert resets for 120 MHz and both 150 MHz domains.
// --FH-4      2026.10.02   OpenAI          CDC cleanup: synchronize reset release to each raw 600 MHz forwarded clock
//                                           before driving BUFGCE_DIV CLR. CLK0 /4 and /5 share one synchronized CLR.
//                                           Divided-domain resets are then derived from the corresponding source-domain reset.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

module gmax3412_iob_clock #(
    parameter CLK_CHAN_NUM = 2
)
(
    input  wire [CLK_CHAN_NUM-1:0] clk_ddr_p,
    input  wire [CLK_CHAN_NUM-1:0] clk_ddr_n,
    input  wire                    reset_n,

    output wire                    clk_rxio0,
    output wire                    clk_rxio0_d4,
    output wire                    clk_rxio1,
    output wire                    clk_rxio1_d4,
    output wire                    clk_rxg,

    // Active-high resets. Assertion is asynchronous to the destination clock;
    // deassertion is synchronized independently in each clock domain.
    output wire                    rst_rxio0_d4,
    output wire                    rst_rxio1_d4,
    output wire                    rst_rxg
);

//////////////////////////////////////////////////////////////////////////////////
// CLK_OUT0 input buffer
//////////////////////////////////////////////////////////////////////////////////
    wire clk_ddr_unbuf0;

    IBUFDS IBUFDS0_inst (
        .O  (clk_ddr_unbuf0),
        .I  (clk_ddr_p[0]),
        .IB (clk_ddr_n[0])
    );

    // Synchronize reset release to the raw forwarded CLK_OUT0 domain.
    // Assertion remains asynchronous; deassertion occurs only on clk_ddr_unbuf0.
    wire div_reset_n0;
    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    (4),
        .INIT_SYNC_FF    (0),
        .RST_ACTIVE_HIGH (0)
    ) u_div_reset0_sync (
        .src_arst  (reset_n),
        .dest_clk  (clk_ddr_unbuf0),
        .dest_arst (div_reset_n0)
    );

//////////////////////////////////////////////////////////////////////////////////
// CLK_OUT0 clock distribution
// 1.20 Gb/s DDR -> 600 MHz forwarded clock
//   /4 = 150 MHz ISERDES CLKDIV
//   /5 = 120 MHz 10-bit word/training clock
//
// IMPORTANT: The /4 and /5 BUFGCE_DIVs share the same source clock, CE and
// active CLR. This is required by Vivado TIMING-49 for deterministic relative
// phase at startup.
//////////////////////////////////////////////////////////////////////////////////
    BUFGCE #(
        .CE_TYPE        ("SYNC"),
        .IS_CE_INVERTED (1'b0),
        .IS_I_INVERTED  (1'b0),
        .SIM_DEVICE     ("ULTRASCALE_PLUS")
    ) BUFGCE0_inst (
        .O  (clk_rxio0),
        .CE (1'b1),
        .I  (clk_ddr_unbuf0)
    );

    BUFGCE_DIV #(
        .BUFGCE_DIVIDE   (4),
        .IS_CE_INVERTED  (1'b0),
        .IS_CLR_INVERTED (1'b1),   // reset_n is active low
        .IS_I_INVERTED   (1'b0),
        .SIM_DEVICE      ("ULTRASCALE_PLUS")
    ) BUFGCE0_DIV_inst (
        .O   (clk_rxio0_d4),
        .CE  (1'b1),
        .CLR (div_reset_n0),
        .I   (clk_ddr_unbuf0)
    );

    BUFGCE_DIV #(
        .BUFGCE_DIVIDE   (5),
        .IS_CE_INVERTED  (1'b0),
        .IS_CLR_INVERTED (1'b1),   // same active clear as /4 divider
        .IS_I_INVERTED   (1'b0),
        .SIM_DEVICE      ("ULTRASCALE_PLUS")
    ) BUFGCE_RXG_DIV5_inst (
        .O   (clk_rxg),
        .CE  (1'b1),
        .CLR (div_reset_n0),
        .I   (clk_ddr_unbuf0)
    );

//////////////////////////////////////////////////////////////////////////////////
// CLK_OUT1 input buffer and distribution
//////////////////////////////////////////////////////////////////////////////////
    wire clk_ddr_unbuf1;

    IBUFDS IBUFDS1_inst (
        .O  (clk_ddr_unbuf1),
        .I  (clk_ddr_p[1]),
        .IB (clk_ddr_n[1])
    );

    // Synchronize reset release to the raw forwarded CLK_OUT1 domain.
    wire div_reset_n1;
    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    (4),
        .INIT_SYNC_FF    (0),
        .RST_ACTIVE_HIGH (0)
    ) u_div_reset1_sync (
        .src_arst  (reset_n),
        .dest_clk  (clk_ddr_unbuf1),
        .dest_arst (div_reset_n1)
    );

    BUFGCE #(
        .CE_TYPE        ("SYNC"),
        .IS_CE_INVERTED (1'b0),
        .IS_I_INVERTED  (1'b0),
        .SIM_DEVICE     ("ULTRASCALE_PLUS")
    ) BUFGCE1_inst (
        .O  (clk_rxio1),
        .CE (1'b1),
        .I  (clk_ddr_unbuf1)
    );

    BUFGCE_DIV #(
        .BUFGCE_DIVIDE   (4),
        .IS_CE_INVERTED  (1'b0),
        .IS_CLR_INVERTED (1'b1),
        .IS_I_INVERTED   (1'b0),
        .SIM_DEVICE      ("ULTRASCALE_PLUS")
    ) BUFGCE1_DIV_inst (
        .O   (clk_rxio1_d4),
        .CE  (1'b1),
        .CLR (div_reset_n1),
        .I   (clk_ddr_unbuf1)
    );

//////////////////////////////////////////////////////////////////////////////////
// Reset synchronizers
//
// Use reset_n directly as the asynchronous reset source.  RST_ACTIVE_HIGH=0
// avoids inserting a LUT into the asynchronous reset source path.  The XPM
// outputs are active low; invert only after synchronization for ordinary
// synchronous reset use inside each destination domain.
//////////////////////////////////////////////////////////////////////////////////
    wire rstn_rxio0_d4;
    wire rstn_rxio1_d4;
    wire rstn_rxg;

    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    (4),
        .INIT_SYNC_FF    (0),
        .RST_ACTIVE_HIGH (0)
    ) u_rst_rxio0_d4_sync (
        .src_arst  (div_reset_n0),
        .dest_clk  (clk_rxio0_d4),
        .dest_arst (rstn_rxio0_d4)
    );

    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    (4),
        .INIT_SYNC_FF    (0),
        .RST_ACTIVE_HIGH (0)
    ) u_rst_rxio1_d4_sync (
        .src_arst  (div_reset_n1),
        .dest_clk  (clk_rxio1_d4),
        .dest_arst (rstn_rxio1_d4)
    );

    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    (4),
        .INIT_SYNC_FF    (0),
        .RST_ACTIVE_HIGH (0)
    ) u_rst_rxg_sync (
        .src_arst  (div_reset_n0),
        .dest_clk  (clk_rxg),
        .dest_arst (rstn_rxg)
    );

    assign rst_rxio0_d4 = ~rstn_rxio0_d4;
    assign rst_rxio1_d4 = ~rstn_rxio1_d4;
    assign rst_rxg       = ~rstn_rxg;

endmodule
