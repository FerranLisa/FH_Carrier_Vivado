`timescale 1ns / 1ps

// FH_Carrier replacement for the FIFO_ICD_W12_D32_RDC IP used by Gpixel's
// iserdes1to10_12.v.
//
// Revision trace
// --------------
// FH-1  2026-10-02  XPM FIFO replacement, 12-bit x 32 words.
// FH-2  2026-10-02  Split reset into independent write/read-domain resets.
//                    This removes the training-reset timing path between the
//                    CLK_OUT0-derived 120 MHz domain and odd-lane CLK_OUT1
//                    150 MHz domain (Vivado TIMING-6/TIMING-7).
//                    Gray-coded pointers cross through XPM synchronizers.
//
// wr_rst and rd_rst are ACTIVE-HIGH and synchronous to wr_clk/rd_clk
// respectively.  They may be asserted together for a complete FIFO flush.

module FIFO_ICD_W12_D32_RDC
(
    input  wire        wr_rst,
    input  wire        rd_rst,

    input  wire        wr_clk,
    input  wire        wr_en,
    input  wire [11:0] din,

    input  wire        rd_clk,
    input  wire        rd_en,
    output reg  [11:0] dout,
    output wire [4:0]  rd_data_count,

    output wire        full,
    output wire        empty
);

    localparam ADDR_WIDTH = 5;   // 32 words
    localparam PTR_WIDTH  = 6;   // extra MSB for wrap/full detection

    (* ram_style = "distributed" *) reg [11:0] mem [0:31];

    reg [PTR_WIDTH-1:0] wr_bin  = {PTR_WIDTH{1'b0}};
    reg [PTR_WIDTH-1:0] wr_gray = {PTR_WIDTH{1'b0}};
    reg                 full_r  = 1'b0;

    reg [PTR_WIDTH-1:0] rd_bin  = {PTR_WIDTH{1'b0}};
    reg [PTR_WIDTH-1:0] rd_gray = {PTR_WIDTH{1'b0}};
    reg                 empty_r = 1'b1;

    wire [PTR_WIDTH-1:0] rd_gray_wsync;
    wire [PTR_WIDTH-1:0] wr_gray_rsync;

    // Gray pointers are registered before crossing.  Only one Gray bit changes
    // per pointer increment, so xpm_cdc_array_single is appropriate here.
    xpm_cdc_array_single #(
        .DEST_SYNC_FF  (2),
        .INIT_SYNC_FF  (0),
        .SIM_ASSERT_CHK(0),
        .SRC_INPUT_REG (0),
        .WIDTH         (PTR_WIDTH)
    ) u_sync_rd_gray_to_wr (
        .src_clk  (rd_clk),
        .src_in   (rd_gray),
        .dest_clk (wr_clk),
        .dest_out (rd_gray_wsync)
    );

    xpm_cdc_array_single #(
        .DEST_SYNC_FF  (2),
        .INIT_SYNC_FF  (0),
        .SIM_ASSERT_CHK(0),
        .SRC_INPUT_REG (0),
        .WIDTH         (PTR_WIDTH)
    ) u_sync_wr_gray_to_rd (
        .src_clk  (wr_clk),
        .src_in   (wr_gray),
        .dest_clk (rd_clk),
        .dest_out (wr_gray_rsync)
    );

    wire wr_take = wr_en && !full_r;
    wire rd_take = rd_en && !empty_r;

    wire [PTR_WIDTH-1:0] wr_bin_next  = wr_bin + {{(PTR_WIDTH-1){1'b0}}, wr_take};
    wire [PTR_WIDTH-1:0] wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;

    wire [PTR_WIDTH-1:0] rd_bin_next  = rd_bin + {{(PTR_WIDTH-1){1'b0}}, rd_take};
    wire [PTR_WIDTH-1:0] rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;

    // Standard asynchronous-FIFO Gray full/empty tests.
    wire full_next =
        (wr_gray_next == {~rd_gray_wsync[PTR_WIDTH-1:PTR_WIDTH-2],
                           rd_gray_wsync[PTR_WIDTH-3:0]});

    wire empty_next = (rd_gray_next == wr_gray_rsync);

    always @(posedge wr_clk) begin
        if (wr_rst) begin
            wr_bin  <= {PTR_WIDTH{1'b0}};
            wr_gray <= {PTR_WIDTH{1'b0}};
            full_r  <= 1'b0;
        end else begin
            if (wr_take)
                mem[wr_bin[ADDR_WIDTH-1:0]] <= din;

            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
            full_r  <= full_next;
        end
    end

    always @(posedge rd_clk) begin
        if (rd_rst) begin
            rd_bin  <= {PTR_WIDTH{1'b0}};
            rd_gray <= {PTR_WIDTH{1'b0}};
            empty_r <= 1'b1;
            dout    <= 12'd0;
        end else begin
            if (rd_take)
                dout <= mem[rd_bin[ADDR_WIDTH-1:0]];

            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
            empty_r <= empty_next;
        end
    end

    function [PTR_WIDTH-1:0] gray_to_bin;
        input [PTR_WIDTH-1:0] gray;
        integer k;
        begin
            gray_to_bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
            for (k = PTR_WIDTH-2; k >= 0; k = k-1)
                gray_to_bin[k] = gray_to_bin[k+1] ^ gray[k];
        end
    endfunction

    wire [PTR_WIDTH-1:0] wr_bin_rsync = gray_to_bin(wr_gray_rsync);
    wire [PTR_WIDTH-1:0] rd_count_ext = wr_bin_rsync - rd_bin;

    // Original Gpixel interface is 5 bits.  Saturate the full-depth value
    // rather than wrap 32 to zero; training only tests for >= 7 words.
    assign rd_data_count = rd_count_ext[PTR_WIDTH-1] ? 5'd31 : rd_count_ext[4:0];

    assign full  = full_r;
    assign empty = empty_r;

endmodule
