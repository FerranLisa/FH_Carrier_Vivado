`timescale 1ns / 1ps
/*
 * FH_Carrier PCIe reference-clock monitor
 *
 * Target:
 *   PZ-ZU7EV / XCZU7EV
 *   M2_PCIE_REFCLK_SOM_P/N -> GTH Bank 223 MGTREFCLK0
 *
 * The 100 MHz differential MGT reference clock is received with IBUFDS_GTE4.
 * REFCLK_HROW_CK_SEL=2'b01 makes ODIV2 equal to REFCLK/2 (50 MHz nominal).
 *
 * A free-running counter is maintained in the ODIV2 clock domain. The binary
 * count is converted to Gray code before crossing into the 100 MHz PS FCLK
 * domain. The synchronized count delta over a 10 ms window is exported.
 *
 * Reset strategy:
 *   - sys_resetn comes from proc_sys_reset/peripheral_aresetn.
 *   - Reset assertion is asynchronous in both clock domains.
 *   - Reset deassertion is synchronized independently to clk_100m and
 *     pcie_clk_50m with two-stage synchronizers.
 *
 * Expected result with a 100.000 MHz input:
 *   ODIV2 = 50 MHz
 *   50 MHz * 10 ms = 500000 counts
 *
 * Status:
 *   bit 0 = valid sample available
 *   bit 1 = clock present
 *   bit 2 = frequency within +/-1 % (495000..505000 counts/10 ms)
 *
 * NOTE:
 *   This block is intended for the bring-up image. If a PCIe IP core is later
 *   added, do not instantiate a second IBUFDS_GTE4 on the same MGTREFCLK pins.
 *   Share the existing IBUFDS_GTE4 outputs between the PCIe core and monitor.
 */

module fh_pcie_refclk_monitor #(
    parameter integer SYS_CLK_HZ = 100000000
)(
    input  wire        clk_100m,
    input  wire        sys_resetn,

    input  wire        M2_PCIE_REFCLK_SOM_P,
    input  wire        M2_PCIE_REFCLK_SOM_N,

    output reg  [31:0] clkmon_count_10ms,
    output wire [31:0] clkmon_status
);

    localparam integer WINDOW_CYCLES = SYS_CLK_HZ / 100;  // 10 ms
    localparam [31:0] COUNT_MIN_1PCT = 32'd495000;
    localparam [31:0] COUNT_MAX_1PCT = 32'd505000;
    localparam [31:0] COUNT_PRESENT_MIN = 32'd1000;

    wire pcie_refclk_gt;
    wire pcie_refclk_odiv2;
    wire pcie_clk_50m;

    IBUFDS_GTE4 #(
        .REFCLK_EN_TX_PATH(1'b0),
        .REFCLK_HROW_CK_SEL(2'b01),
        .REFCLK_ICNTL_RX(2'b00)
    ) u_ibufds_gte4_pcie_refclk (
        .O     (pcie_refclk_gt),
        .ODIV2 (pcie_refclk_odiv2),
        .CEB   (1'b0),
        .I     (M2_PCIE_REFCLK_SOM_P),
        .IB    (M2_PCIE_REFCLK_SOM_N)
    );

    BUFG_GT u_bufg_gt_pcie_refclk (
        .O       (pcie_clk_50m),
        .CE      (1'b1),
        .CEMASK  (1'b0),
        .CLR     (1'b0),
        .CLRMASK (1'b0),
        .DIV     (3'b000),
        .I       (pcie_refclk_odiv2)
    );

    /*
     * Reset synchronizers.
     *
     * sys_resetn is asserted asynchronously by proc_sys_reset. Its release is
     * synchronized separately into each local clock domain.
     */
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [1:0] rst100_sync;

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [1:0] rst50_sync;

    always @(posedge clk_100m or negedge sys_resetn) begin
        if (!sys_resetn)
            rst100_sync <= 2'b00;
        else
            rst100_sync <= {rst100_sync[0], 1'b1};
    end

    always @(posedge pcie_clk_50m or negedge sys_resetn) begin
        if (!sys_resetn)
            rst50_sync <= 2'b00;
        else
            rst50_sync <= {rst50_sync[0], 1'b1};
    end

    wire rst100n = rst100_sync[1];
    wire rst50n  = rst50_sync[1];

    /*
     * Counter in the PCIe-reference-clock domain.
     *
     * Assertion is asynchronous through sys_resetn. Deassertion is held until
     * rst50n has been synchronously released in the pcie_clk_50m domain.
     *
     * If the external reference clock disappears, this counter simply stops.
     */
    reg [31:0] pcie_count_bin;

    always @(posedge pcie_clk_50m or negedge sys_resetn) begin
        if (!sys_resetn)
            pcie_count_bin <= 32'd0;
        else if (!rst50n)
            pcie_count_bin <= 32'd0;
        else
            pcie_count_bin <= pcie_count_bin + 32'd1;
    end

    /*
     * Gray encoding means that only one counter bit changes for each increment,
     * making a sampled multi-bit CDC much safer than synchronizing binary bits.
     */
    wire [31:0] pcie_count_gray = pcie_count_bin ^ (pcie_count_bin >> 1);

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [31:0] gray_sync_ff1;

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [31:0] gray_sync_ff2;

    always @(posedge clk_100m or negedge sys_resetn) begin
        if (!sys_resetn) begin
            gray_sync_ff1 <= 32'd0;
            gray_sync_ff2 <= 32'd0;
        end else if (!rst100n) begin
            gray_sync_ff1 <= 32'd0;
            gray_sync_ff2 <= 32'd0;
        end else begin
            gray_sync_ff1 <= pcie_count_gray;
            gray_sync_ff2 <= gray_sync_ff1;
        end
    end

    function automatic [31:0] gray_to_bin;
        input [31:0] gray;
        integer i;
        begin
            gray_to_bin[31] = gray[31];
            for (i = 30; i >= 0; i = i - 1)
                gray_to_bin[i] = gray_to_bin[i + 1] ^ gray[i];
        end
    endfunction

    wire [31:0] pcie_count_sync_bin = gray_to_bin(gray_sync_ff2);

    reg [31:0] previous_count;
    reg [31:0] window_counter;
    reg        sample_valid;
    reg        clock_present;
    reg        frequency_in_range;

    wire [31:0] count_delta = pcie_count_sync_bin - previous_count;

    /*
     * 10 ms measurement window in the 100 MHz system-clock domain.
     */
    always @(posedge clk_100m or negedge sys_resetn) begin
        if (!sys_resetn) begin
            previous_count       <= 32'd0;
            window_counter       <= 32'd0;
            clkmon_count_10ms    <= 32'd0;
            sample_valid         <= 1'b0;
            clock_present        <= 1'b0;
            frequency_in_range   <= 1'b0;
        end else if (!rst100n) begin
            previous_count       <= 32'd0;
            window_counter       <= 32'd0;
            clkmon_count_10ms    <= 32'd0;
            sample_valid         <= 1'b0;
            clock_present        <= 1'b0;
            frequency_in_range   <= 1'b0;
        end else begin
            if (window_counter == WINDOW_CYCLES - 1) begin
                window_counter       <= 32'd0;
                clkmon_count_10ms    <= count_delta;
                previous_count       <= pcie_count_sync_bin;
                sample_valid         <= 1'b1;
                clock_present        <= (count_delta >= COUNT_PRESENT_MIN);
                frequency_in_range   <= (count_delta >= COUNT_MIN_1PCT) &&
                                        (count_delta <= COUNT_MAX_1PCT);
            end else begin
                window_counter <= window_counter + 32'd1;
            end
        end
    end

    assign clkmon_status = {
        29'd0,
        frequency_in_range,
        clock_present,
        sample_valid
    };

    /*
     * Keep the direct MGT reference-clock output available for easy future
     * sharing with a PCIe core. It is intentionally unused by this monitor.
     */
    wire unused_pcie_refclk_gt;
    assign unused_pcie_refclk_gt = pcie_refclk_gt;

endmodule
