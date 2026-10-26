`timescale 1ns/1ps
module tb_gmax3412_scheduler;
 parameter LIVE=0;
 reg clk=0;always #4 clk=~clk;
 reg resetn=0;reg [31:0] control=0;wire [31:0] status;
 wire [31:0] awaddr,wdata,araddr;wire awvalid,wvalid,arvalid,bready,rready;
 reg awready=0,wready=0,arready=0,bvalid=0,rvalid=0;
 reg [1:0] bresp=0,rresp=0;reg [31:0] rdata=0;
 wire [2:0] awprot,arprot;wire [3:0] wstrb;
 gmax3412_scheduler #(.RESET_WAIT(LIVE ? 12000 : 12),.POLL_LIMIT(LIVE ? 240000000 : 20000)) dut(
 .clk(clk),.resetn(resetn),.control(control),.status(status),
 .m_axi_awaddr(awaddr),.m_axi_awprot(awprot),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
 .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
 .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
 .m_axi_araddr(araddr),.m_axi_arprot(arprot),.m_axi_arvalid(arvalid),.m_axi_arready(arready),
 .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),.m_axi_rready(rready));
 integer tick=0,triggers=0,frames=0,delay_count=0,fault=0;
 reg bus_fault_sent=0;
 reg gota=0,gotw=0;reg [31:0] a,d,lo,hi,seed;
 reg enabled=0,armed=0,finished=0;
 reg [63:0] expected;
 reg src_init=0,src_start=0,src_stop=0,src_trigger=0;
 reg [31:0] bridge_control=0;
 wire fv,lv,src_initialized,src_armed,src_busy,exposing;
 wire [191:0] pixels;wire [9:0] active_seed;
 wire [31:0] accepted,rejected,checked,errors,npix,nlines,sum;
 wire pass;wire [31:0] bridge_status;
 wire [127:0] stream_data;wire [15:0] stream_keep;wire stream_valid,stream_last;
 wire stream_ready=LIVE && armed && tick%4!=0;
 integer received=0,stream_frames=0,j,want;
 gmax3412_pattern source_model(.clk(clk),.resetn(resetn),.init_cmd(src_init),
 .start_cmd(src_start),.stop_cmd(src_stop),.trigger_cmd(src_trigger),
 .exposure_cycles(32'd20),.blank_cycles(32'd1024),.seed(seed[9:0]),
 .initialized(src_initialized),.armed(src_armed),.busy(src_busy),.exposing(exposing),
 .fval(fv),.lval(lv),.data(pixels),.active_seed(active_seed),.accepted(accepted),.rejected(rejected));
 gmax3412_checker image_checker(.clk(clk),.resetn(resetn),.fval(fv),.lval(lv),.data(pixels),.seed(active_seed),
 .frames(checked),.errors(errors),.last_pixels(npix),.last_lines(nlines),.checksum(sum),.last_pass(pass));
 gmax3412_capture bridge(.clk(clk),.resetn(resetn),.control(bridge_control),.status(bridge_status),
 .emu_clk(clk),.emu_fval(fv),.emu_lval(lv),.emu_data(pixels),
 .rx_clk(clk),.rx_fval(1'b0),.rx_lval(1'b0),.rx_data(192'b0),
 .m_axis_tdata(stream_data),.m_axis_tkeep(stream_keep),.m_axis_tvalid(stream_valid),
 .m_axis_tready(stream_ready),.m_axis_tlast(stream_last));
 always @(negedge clk) begin
  tick=tick+1;awready=(tick%3==0);wready=(tick%4==0);arready=(tick%5==0);
 end
 always @(posedge clk) if(resetn) begin
  src_trigger<=0;src_stop<=0;
  if(LIVE && stream_valid && stream_ready) begin
   if(stream_keep!=16'hffff) $fatal(1,"Stream keep");
   for(j=0;j<8;j=j+1) begin
    want=((received+j)%4096+(received+j)/4096+active_seed)&1023;
    if(stream_data[j*16+:16]!==want[15:0]) $fatal(1,"Stream pixel %d",received+j);
   end
   received=received+8;
   if(stream_last !== (received==12582912)) $fatal(1,"Stream frame length");
   if(stream_last) begin finished<=1;stream_frames=stream_frames+1;end
  end
  if(awvalid&&awready) begin a<=awaddr;gota<=1;end
  if(wvalid&&wready) begin d<=wdata;gotw<=1;end
  if(bvalid&&bready) bvalid<=0;
  if(rvalid&&rready) rvalid<=0;
  if(gota&&gotw&&!bvalid) begin
   gota<=0;gotw<=0;bvalid<=1;bresp<=0;
   case(a)
    'hA0040000:begin bridge_control<=d;enabled<=d==1;if(d!=1) finished<=0;end
    'hA0050030:if(d==4) begin armed<=0;end
    'hA0050048:lo<=d;
    'hA005004C:hi<=d;
    'hA0030014:seed<=d;
    'hA0050058:begin
      if(d!=25165824) $fatal(1,"Wrong frame length");
      expected=frames<74 ? 64'h10000040+frames*64'd25165952 : 64'h800000040+(frames-74)*64'd25165952;
      if({hi,lo}!=expected) $fatal(1,"Address mismatch frame %d got %h expected %h",frames,{hi,lo},expected);
      armed<=1;received=0;
    end
    'hA0030004:if(d==8) begin
      if(!armed||!enabled||seed!=((7+37*frames)&1023)) $fatal(1,"Trigger before arm / wrong seed");
      triggers<=triggers+1;delay_count<=80;frames<=frames+1;src_trigger<=LIVE;
    end else if(d==4) src_stop<=LIVE;
    default:begin end
   endcase
  end
  if(!LIVE && delay_count>0) begin delay_count<=delay_count-1;if(delay_count==1 && fault!=3) finished<=1;end
  if(arvalid&&arready) begin
   rvalid<=1;rresp<=0;
   if(fault==4 && !bus_fault_sent) begin rresp<=2;bus_fault_sent<=1;end
   case(araddr)
    'hA0050030:rdata<=0;
    'hA0050034:rdata<=fault==1 ? 'h10 : (finished ? 'h1002 : 0);
    'hA0040008:rdata<=LIVE ? bridge_status : (fault==2 ? 'h1A : (finished ? 'h47 : (enabled ? 3 : 0)));
    'hA0030008:rdata<=LIVE ? {27'b0,pass,exposing,src_busy,src_armed,src_initialized} : 'h13;
    default:$fatal(1,"Unexpected read");
   endcase
  end
 end
 task cmd(input [2:0] op,input [7:0] n);
 begin @(negedge clk);control={~control[31],op,12'b0,n,8'b0};repeat(4) @(negedge clk);end
 endtask
 task bank(input [3:0] n);
 begin @(negedge clk);control[3:0]=n;#1;end
 endtask
 task runburst(input integer count,input integer inject);
 integer limit;
 begin
  frames=0;triggers=0;fault=inject;bus_fault_sent=0;cmd(1,count);cmd(2,0);
  bank(1);limit=0;
  while(status[0] && limit<(LIVE ? 100000000 : 1000000)) begin @(negedge clk);limit=limit+1;end
  if(status[0]) $fatal(1,"Scheduler hung");
  if(inject==0) begin
   if(!status[1] || status[2] || triggers!=count) $fatal(1,"Burst failed");
   bank(3);if(status!=count) $fatal(1,"Wrong completed count");
  end else begin
   if(!status[2] || status[1] || enabled || armed) $fatal(1,"Error cleanup failed");
  end
 end
 endtask
 initial begin
  repeat(8) @(negedge clk);resetn=1;
  if(LIVE) begin
   @(negedge clk);src_init=1;@(negedge clk);src_init=0;
   wait(src_initialized);@(negedge clk);src_start=1;@(negedge clk);src_start=0;
   wait(src_armed);runburst(4,0);
   if(stream_frames!=4 || checked!=4 || errors!=0 || accepted!=4 || rejected!=0) $fatal(1,"Live counters");
   $display("SCHEDULER_LIVE_PASS: four real 4096x3072 frames, all stream pixels, source checker, FIFO rearm, AXIS backpressure, autonomous triggering");$finish;
  end
  cmd(1,3);bank(4);if(status!=1) $fatal(1,"Accepted capacity 3");
  cmd(2,0);bank(1);if(status[0]) $fatal(1,"Started invalid capacity");
  cmd(1,120);bank(4);if(status!=1) $fatal(1,"Accepted capacity 120");
  runburst(4,0);runburst(119,0);runburst(4,1);runburst(4,2);runburst(4,3);runburst(4,4);runburst(5,0);
  frames=0;triggers=0;cmd(1,119);cmd(2,0);
  wait(triggers==2);cmd(3,0);bank(1);wait(!status[0]);#1;
  if(!status[3] || status[1] || status[2] || triggers!=2) $fatal(1,"Graceful stop failed");
  runburst(4,0);
  $display("SCHEDULER_TEST_PASS: capacity bounds, 119 frames, high DDR transition, split AXI handshakes, DMA/capture/bus errors, timeout, stop, recovery");$finish;
 end
 initial begin #(LIVE ? 500000000 : 100000000);$fatal(1,"Watchdog");end
endmodule
