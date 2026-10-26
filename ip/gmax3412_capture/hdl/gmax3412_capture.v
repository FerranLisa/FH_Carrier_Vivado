`timescale 1ns/1ps
module gmax3412_capture #(parameter WIDTH=4096, HEIGHT=3072, DEPTH=1024)(
 (* X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF m_axis, ASSOCIATED_RESET resetn, FREQ_HZ 120000000" *)
 input wire clk,
 (* X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input wire resetn,
 input wire [31:0] control, output reg [31:0] status,
 input wire emu_clk,emu_fval,emu_lval,input wire [191:0] emu_data,
 input wire rx_clk,rx_fval,rx_lval,input wire [191:0] rx_data,
 output wire [127:0] m_axis_tdata,output wire [15:0] m_axis_tkeep,
 output wire m_axis_tvalid,input wire m_axis_tready,output wire m_axis_tlast
);
 reg active=0,selected=0,done=0,half=0;
 reg [31:0] bytes_sent=0,frames=0,overflows=0,bad_frames=0,drops=0;
 reg oldov=0,oldgeo=0,olddrop=0;
 wire [256:0] d0,d1;
 wire e0,e1,r0,r1,f0,f1,o0,o1,g0,g1,k0,k1;
 wire go=active && control[0] && !control[2];
 wire [256:0] data=selected ? d1:d0;
 wire empty=selected ? e1:e0;
 wire ready=selected ? r1:r0;
 wire finished=selected ? f1:f0;
 wire ov=selected ? o1:o0;
 wire geo=selected ? g1:g0;
 wire drop=selected ? k1:k0;
 wire fire=m_axis_tvalid && m_axis_tready;
 wire pop=fire && half;
 gmax3412_capture_source #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.DEPTH(DEPTH)) emu (
 .src_clk(emu_clk),.dst_clk(clk),.resetn(resetn),.request(go && !selected),
 .fval(emu_fval),.lval(emu_lval),.data(emu_data),.fifo_data(d0),.empty(e0),
 .pop(pop && !selected),.ready(r0),.finished(f0),.overflow(o0),.geometry(g0),.dropped(k0));
 gmax3412_capture_source #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.DEPTH(DEPTH)) rx (
 .src_clk(rx_clk),.dst_clk(clk),.resetn(resetn),.request(go && selected),
 .fval(rx_fval),.lval(rx_lval),.data(rx_data),.fifo_data(d1),.empty(e1),
 .pop(pop && selected),.ready(r1),.finished(f1),.overflow(o1),.geometry(g1),.dropped(k1));
 assign m_axis_tdata=half ? data[255:128] : data[127:0];
 assign m_axis_tkeep=16'hffff;
 // A failed frame is drained normally where possible. Software resets DMA on
 // an incomplete transfer; error flags never cause a false success.
 assign m_axis_tvalid=go && !done && !empty;
 assign m_axis_tlast=data[256] && half;
 always @(posedge clk) begin
   if(!resetn) begin
     active<=0;selected<=0;done<=0;half<=0;bytes_sent<=0;
     frames<=0;overflows<=0;bad_frames<=0;drops<=0;
     oldov<=0;oldgeo<=0;olddrop<=0;
   end else begin
     oldov<=go && ov;oldgeo<=go && geo;olddrop<=go && drop;
     if(go && ov && !oldov) overflows<=overflows+1;
     if(go && geo && !oldgeo) bad_frames<=bad_frames+1;
     if(go && drop && !olddrop) drops<=drops+1;
     if(!control[0] || control[2]) begin
       active<=0;done<=0;half<=0;bytes_sent<=0;
     end else if(!active) begin
       active<=1;selected<=control[1];done<=0;half<=0;bytes_sent<=0;
     end else if(fire) begin
       half<=!half;bytes_sent<=bytes_sent+16;
       if(m_axis_tlast) begin done<=1;frames<=frames+1;end
     end
   end
 end
 always @* begin
   case(control[7:4])
     0: status={24'b0,selected,finished,drop,geo,ov,done,active,go && ready};
     1: status=32'h3412ca01;
     2: status=bytes_sent;
     3: status=frames;
     4: status=overflows;
     5: status=bad_frames;
     6: status=drops;
     7: status=WIDTH*HEIGHT*2;
     // Physical source is wired but the current adapter has no image sync.
     8: status=32'h00000001; // available sources: emulator only
     default: status=0;
   endcase
 end
endmodule
