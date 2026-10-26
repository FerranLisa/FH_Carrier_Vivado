`timescale 1ns/1ps
// UG571: bank 65 multi-function DCI pins require a post-configuration reset.
// Use the independent 120 MHz emulator clock, never the DDR UI clock.
module pl_ddr_dci_reset (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER = "ASSOCIATED_RESET resetn" *) input wire clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 resetn RST", X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *) input wire resetn,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 sys_rst RST", X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *) output wire sys_rst
);
    wire dci_reset, dci_locked;
    DCIRESET u_dcirst (.RST(dci_reset), .LOCKED(dci_locked));
    pl_ddr_dci_sequence u_sequence (.clk(clk), .resetn(resetn),
        .dci_locked(dci_locked), .dci_reset(dci_reset), .sys_rst(sys_rst));
endmodule

module pl_ddr_dci_sequence (
    input wire clk, resetn, dci_locked,
    output reg dci_reset = 1'b0,
    output wire sys_rst
);
    reg [6:0] count = 0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] lock_sync = 0;
    reg ready = 0;
    assign sys_rst = ~ready;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            count <= 0;
            dci_reset <= 0;
            lock_sync <= 0;
            ready <= 0;
        end else begin
            if (count != 127) count <= count + 1'b1;
            // Start after 32 clocks; hold reset for 64 clocks (533 ns).
            dci_reset <= (count >= 31 && count < 95);
            if (count < 96) lock_sync <= 0;
            else lock_sync <= {lock_sync[0], dci_locked};
            // Registered reset release, only after the pulse and DCI lock.
            ready <= (count == 127 && lock_sync[1]);
        end
    end
endmodule
