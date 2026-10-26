`timescale 1ns / 1ps

module gmax3412_clk_probe
(
    input  wire GMX_CLK0_P,
    input  wire GMX_CLK0_N,

    input  wire GMX_CLK1_P,
    input  wire GMX_CLK1_N
);

    // Raw differential receiver outputs.
    wire clk0_raw;
    wire clk1_raw;

    // Divided clocks:
    // 1.28 Gb/s DDR => 640 MHz clock
    // /8 => nominal 80 MHz, easy for fabric/debug.
    wire clk0_div8;
    wire clk1_div8;


    // ============================================================
    // Differential input buffers
    //
    // Electrical standard and 100-ohm termination are assigned
    // in the XDC, not here.
    // ============================================================

    IBUFDS u_clk0_ibufds
    (
        .I  (GMX_CLK0_P),
        .IB (GMX_CLK0_N),
        .O  (clk0_raw)
    );

    IBUFDS u_clk1_ibufds
    (
        .I  (GMX_CLK1_P),
        .IB (GMX_CLK1_N),
        .O  (clk1_raw)
    );


    // ============================================================
    // Divide high-speed clocks by 8 for debug/counters.
    // 640 MHz / 8 = 80 MHz nominal.
    // ============================================================

    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(8),
        .SIM_DEVICE("ULTRASCALE_PLUS")
    )
    u_clk0_div
    (
        .I   (clk0_raw),
        .CE  (1'b1),
        .CLR (1'b0),
        .O   (clk0_div8)
    );

    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(8),
        .SIM_DEVICE("ULTRASCALE_PLUS")
    )
    u_clk1_div
    (
        .I   (clk1_raw),
        .CE  (1'b1),
        .CLR (1'b0),
        .O   (clk1_div8)
    );


    // ============================================================
    // Simple activity counters.
    //
    // MARK_DEBUG keeps them available for Vivado Hardware Manager.
    // ============================================================

    (* MARK_DEBUG = "TRUE" *)
    reg [31:0] clk0_counter = 32'd0;

    (* MARK_DEBUG = "TRUE" *)
    reg [31:0] clk1_counter = 32'd0;


    always @(posedge clk0_div8)
        clk0_counter <= clk0_counter + 1'b1;

    always @(posedge clk1_div8)
        clk1_counter <= clk1_counter + 1'b1;


    // Keep the divided clocks visible for debug setup as well.

    (* MARK_DEBUG = "TRUE" *)
    wire clk0_div8_debug = clk0_div8;

    (* MARK_DEBUG = "TRUE" *)
    wire clk1_div8_debug = clk1_div8;

endmodule
