`timescale 1ns/1ps
module gmax3412_emulator #(
    parameter integer IMAGE_WIDTH=4096, IMAGE_HEIGHT=3072
)(
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 s_axi_aclk CLK", X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 120000000" *)
    input wire s_axi_aclk,
    (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 s_axi_aresetn RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *)
    input wire s_axi_aresetn,
    input wire [7:0] s_axi_awaddr,
    input wire [2:0] s_axi_awprot,
    input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb,
    input wire s_axi_wvalid, output wire s_axi_wready,
    output reg [1:0] s_axi_bresp, output reg s_axi_bvalid,
    input wire s_axi_bready,
    input wire [7:0] s_axi_araddr, input wire [2:0] s_axi_arprot,
    input wire s_axi_arvalid, output wire s_axi_arready,
    output reg [31:0] s_axi_rdata, output reg [1:0] s_axi_rresp,
    output reg s_axi_rvalid, input wire s_axi_rready,
    // Native commands: synchronous rising edges in the 120 MHz domain.
    input wire init_in, acquisition_start, acquisition_stop, trigger_in,
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk_rxg CLK", X_INTERFACE_PARAMETER="FREQ_HZ 120000000" *)
    output wire clk_rxg,
    (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 rst_rxg RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_HIGH" *)
    output wire rst_rxg,
    output wire fvalout, lvalout, output wire [191:0] dataout,
    output wire initialized, armed, busy, cmos_texp1, cmos_texp2
);
    reg aw_pending, w_pending;
    reg [7:0] awaddr;
    reg [31:0] wdata;
    reg [3:0] wstrb;
    reg [31:0] exposure, blanking, seed_reg;
    reg [3:0] commands, native_prev;
    wire [3:0] native_now={trigger_in,acquisition_stop,acquisition_start,init_in};
    wire [3:0] cmd=commands | (native_now & ~native_prev);
    wire [31:0] accepted,rejected,frames,errors,pixels,lines,checksum;
    wire pass;
    wire [31:0] tm_seq,tm_exp,tm_lmin,tm_lmax,tm_bmin,tm_bmax,tm_frame,tm_lines;
    gmax3412_timing timing_monitor(.clk(s_axi_aclk),.resetn(s_axi_aresetn),
        .exposing(cmos_texp1),.fval(fvalout),.lval(lvalout),
        .sequence_number(tm_seq),.exposure_cycles(tm_exp),.line_min(tm_lmin),.line_max(tm_lmax),
        .blank_min(tm_bmin),.blank_max(tm_bmax),.frame_cycles(tm_frame),.line_count(tm_lines));
    wire [9:0] active_seed;
    assign clk_rxg=s_axi_aclk;
    assign rst_rxg=~s_axi_aresetn;
    assign cmos_texp2=1'b0;
    assign s_axi_awready=!aw_pending && !s_axi_bvalid;
    assign s_axi_wready=!w_pending && !s_axi_bvalid;
    assign s_axi_arready=!s_axi_rvalid;
    integer b;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            aw_pending<=0; w_pending<=0; awaddr<=0; wdata<=0; wstrb<=0;
            s_axi_bresp<=0; s_axi_bvalid<=0; s_axi_rdata<=0;
            s_axi_rresp<=0; s_axi_rvalid<=0;
            exposure<=120000; blanking<=16; seed_reg<=0;
            commands<=0; native_prev<=0;
        end else begin
            commands<=0; native_prev<=native_now;
            if (s_axi_awvalid && s_axi_awready) begin
                aw_pending<=1; awaddr<=s_axi_awaddr;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                w_pending<=1; wdata<=s_axi_wdata; wstrb<=s_axi_wstrb;
            end
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid<=0;
            if (aw_pending && w_pending && !s_axi_bvalid) begin
                aw_pending<=0; w_pending<=0; s_axi_bvalid<=1; s_axi_bresp<=0;
                case (awaddr)
                    8'h04: if (wstrb[0]) commands<=wdata[3:0];
                    8'h0c: for(b=0;b<4;b=b+1) if(wstrb[b]) exposure[b*8 +: 8]<=wdata[b*8 +: 8];
                    8'h10: for(b=0;b<4;b=b+1) if(wstrb[b]) blanking[b*8 +: 8]<=wdata[b*8 +: 8];
                    8'h14: for(b=0;b<4;b=b+1) if(wstrb[b]) seed_reg[b*8 +: 8]<=wdata[b*8 +: 8];
                    default: s_axi_bresp<=2'b10;
                endcase
            end
            if(s_axi_rvalid && s_axi_rready) s_axi_rvalid<=0;
            if(s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid<=1; s_axi_rresp<=0;
                case(s_axi_araddr)
                    8'h00: s_axi_rdata<=32'h34120001;
                    8'h04: s_axi_rdata<=0;
                    8'h08: s_axi_rdata<={27'b0,pass,cmos_texp1,busy,armed,initialized};
                    8'h0c: s_axi_rdata<=exposure;
                    8'h10: s_axi_rdata<=blanking;
                    8'h14: s_axi_rdata<=seed_reg;
                    8'h18: s_axi_rdata<=IMAGE_WIDTH;
                    8'h1c: s_axi_rdata<=IMAGE_HEIGHT;
                    8'h20: s_axi_rdata<=accepted;
                    8'h24: s_axi_rdata<=rejected;
                    8'h28: s_axi_rdata<=frames;
                    8'h2c: s_axi_rdata<=errors;
                    8'h30: s_axi_rdata<=pixels;
                    8'h34: s_axi_rdata<=lines;
                    8'h38: s_axi_rdata<=checksum;
                    8'h3c: s_axi_rdata<=120000000;
                    8'h40: s_axi_rdata<=32'h544d0001;
                    8'h44: s_axi_rdata<=tm_seq;
                    8'h48: s_axi_rdata<=tm_exp;
                    8'h4c: s_axi_rdata<=tm_lmin;
                    8'h50: s_axi_rdata<=tm_lmax;
                    8'h54: s_axi_rdata<=tm_bmin;
                    8'h58: s_axi_rdata<=tm_bmax;
                    8'h5c: s_axi_rdata<=tm_frame;
                    8'h60: s_axi_rdata<=tm_lines;
                    default: begin s_axi_rdata<=0; s_axi_rresp<=2'b10; end
                endcase
            end
        end
    end
    gmax3412_pattern #(.WIDTH(IMAGE_WIDTH),.HEIGHT(IMAGE_HEIGHT)) source (
        .clk(s_axi_aclk),.resetn(s_axi_aresetn),
        .init_cmd(cmd[0]),.start_cmd(cmd[1]),.stop_cmd(cmd[2]),.trigger_cmd(cmd[3]),
        .exposure_cycles(exposure),.blank_cycles(blanking),.seed(seed_reg[9:0]),
        .initialized(initialized),.armed(armed),.busy(busy),.exposing(cmos_texp1),
        .fval(fvalout),.lval(lvalout),.data(dataout),.active_seed(active_seed),
        .accepted(accepted),.rejected(rejected));
    gmax3412_checker #(.WIDTH(IMAGE_WIDTH),.HEIGHT(IMAGE_HEIGHT)) checker_inst (
        .clk(s_axi_aclk),.resetn(s_axi_aresetn),.fval(fvalout),.lval(lvalout),
        .data(dataout),.seed(active_seed),.frames(frames),.errors(errors),
        .last_pixels(pixels),.last_lines(lines),.checksum(checksum),.last_pass(pass));
endmodule
