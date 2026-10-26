`timescale 1ns/1ps
// Finite autonomous burst. GPIO command/status interface; AXI-Lite control master.
// Storage is fixed to reserved DDR apertures; software cannot supply DMA addresses.
module gmax3412_scheduler #(parameter RESET_WAIT=12000, POLL_LIMIT=240000000)(
 (* X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF M_AXI, ASSOCIATED_RESET resetn, FREQ_HZ 120000000" *) input wire clk,
 (* X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input wire resetn,
 input wire [31:0] control, output reg [31:0] status,
 output reg [31:0] m_axi_awaddr, output wire [2:0] m_axi_awprot,
 output reg m_axi_awvalid, input wire m_axi_awready,
 output reg [31:0] m_axi_wdata, output wire [3:0] m_axi_wstrb,
 output reg m_axi_wvalid, input wire m_axi_wready,
 input wire [1:0] m_axi_bresp,input wire m_axi_bvalid,output wire m_axi_bready,
 output reg [31:0] m_axi_araddr,output wire [2:0] m_axi_arprot,
 output reg m_axi_arvalid,input wire m_axi_arready,
 input wire [31:0] m_axi_rdata,input wire [1:0] m_axi_rresp,
 input wire m_axi_rvalid,output wire m_axi_rready
);
 localparam STRIDE=32'd25165952;
 reg toggle, running, done, stopped, stop_request;
 reg [7:0] capacity, completed, state;
 reg [31:0] error, timer, cycles, last_dma, last_cap;
 reg [63:0] destination;
 reg [1:0] bus;
 reg response;
 reg [31:0] readback;
 wire command=control[31]!=toggle;
 assign m_axi_awprot=0;assign m_axi_arprot=0;assign m_axi_wstrb=15;
 assign m_axi_bready=bus==1;assign m_axi_rready=bus==2;
 task write_reg(input [31:0] a,input [31:0] d);
 begin m_axi_awaddr<=a;m_axi_wdata<=d;m_axi_awvalid<=1;m_axi_wvalid<=1;bus<=1;end
 endtask
 task read_reg(input [31:0] a);
 begin m_axi_araddr<=a;m_axi_arvalid<=1;bus<=2;end
 endtask
 always @* begin
   case(control[3:0])
    0:status=32'h34125301;
    1:status={16'b0,state,4'b0,stopped,(error!=0),done,running};
    2:status={24'b0,capacity};3:status={24'b0,completed};
    4:status=error;5:status=cycles;6:status=last_dma;7:status=last_cap;
    8:status=32'd119;9:status=STRIDE;10:status=destination[31:0];
    11:status=destination[63:32];default:status=0;
   endcase
 end
 always @(posedge clk) begin
  if(!resetn) begin
   toggle<=0;running<=0;done<=0;stopped<=0;stop_request<=0;
   capacity<=4;completed<=0;state<=0;error<=0;timer<=0;cycles<=0;
   last_dma<=0;last_cap<=0;destination<=0;bus<=0;response<=0;readback<=0;
   m_axi_awvalid<=0;m_axi_wvalid<=0;m_axi_arvalid<=0;
   m_axi_awaddr<=0;m_axi_wdata<=0;m_axi_araddr<=0;
  end else begin
   response<=0;
   if(m_axi_awvalid && m_axi_awready) m_axi_awvalid<=0;
   if(m_axi_wvalid && m_axi_wready) m_axi_wvalid<=0;
   if(m_axi_arvalid && m_axi_arready) m_axi_arvalid<=0;
   if(bus==1 && m_axi_bvalid) begin
    bus<=0;response<=1;
    if(m_axi_bresp!=0) begin error<=2;state<=90;end
   end
   if(bus==2 && m_axi_rvalid) begin
    bus<=0;response<=1;readback<=m_axi_rdata;
    if(m_axi_rresp!=0) begin error<=2;state<=90;end
   end
   if(command) begin
    toggle<=control[31];
    case(control[30:28])
     1:if(!running) begin
        if(control[15:8]>=4 && control[15:8]<=119) begin capacity<=control[15:8];error<=0;end
        else error<=1;
       end
     2:if(!running && error==0) begin
        running<=1;done<=0;stopped<=0;stop_request<=0;completed<=0;
        cycles<=0;timer<=0;state<=1;destination<=64'h10000040;
       end
     3:if(running) stop_request<=1;
     default:begin end
    endcase
   end
   if(running) begin
    cycles<=cycles+1;
    if(timer<POLL_LIMIT) timer<=timer+1;
    // Never withdraw an AXI request. A stalled bus remains owned until response.
    if(bus==0 && !response) begin
     if(timer==POLL_LIMIT && state<90) begin error<=3;state<=90;end
     else case(state)
      1:begin write_reg(32'hA0050030,4);state<=2;end
      2:begin read_reg(32'hA0050030);state<=3;end
      3:if(readback[2]) state<=2;else begin timer<=0;state<=10;end
      10:begin write_reg(32'hA0040000,0);timer<=0;state<=11;end
      11:if(timer>=RESET_WAIT) state<=12;
      12:begin write_reg(32'hA0030014,(7+37*completed)&1023);state<=13;end
      13:begin write_reg(32'hA0050034,32'h7000);state<=14;end
      14:begin write_reg(32'hA0050030,1);state<=15;end
      15:begin write_reg(32'hA005004C,destination[63:32]);state<=16;end
      16:begin write_reg(32'hA0050048,destination[31:0]);state<=17;end
      17:begin write_reg(32'hA0050058,32'd25165824);state<=18;end
      18:begin write_reg(32'hA0040000,1);state<=19;end
      19:begin read_reg(32'hA0040008);state<=20;end
      20:if(readback[0]) state<=21;else state<=19;
      21:begin write_reg(32'hA0030004,8);timer<=0;state<=22;end
      22:begin read_reg(32'hA0050034);state<=23;end
      23:begin
       last_dma<=readback;
       if((readback&32'h770)!=0) begin error<=4;state<=90;end
       else state<=24;
      end
      24:begin read_reg(32'hA0040008);state<=25;end
      25:begin
       last_cap<=readback;
       if((readback&32'h38)!=0) begin error<=5;state<=90;end
       else if((readback&32'h44)==32'h44 && (last_dma&32'h1002)==32'h1002) state<=26;
       else state<=22;
      end
      26:begin read_reg(32'hA0030008);state<=27;end
      27:if(readback[2]) state<=26;
         else if(!readback[4]) begin error<=6;state<=90;end
         else begin
          completed<=completed+1;timer<=0;
          if(completed+1==capacity || stop_request) state<=90;
          else begin
           // 74 guarded frames fit below 0x7FF00000; continue in high DDR.
           if(completed==73) destination<=64'h800000040;
           else destination<=destination+STRIDE;
           state<=10;
          end
         end
      90:begin write_reg(32'hA0040000,4);state<=91;end
      91:begin write_reg(32'hA0030004,4);state<=92;end
      92:begin write_reg(32'hA0050030,4);state<=93;end
      93:begin read_reg(32'hA0050030);state<=94;end
      94:if(readback[2]) state<=93;else begin
         running<=0;done<=error==0 && completed==capacity;
         stopped<=stop_request;state<=0;
         end
      default:begin error<=7;state<=90;end
     endcase
    end
   end
  end
 end
endmodule
