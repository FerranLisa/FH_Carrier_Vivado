`timescale 1ns/1ps
module tb_gmax3412_capture;
 parameter W=4096,H=3072;
 reg clk=0,src_clk=0,rx_clk=0,resetn=0;
 always #4.167 clk=~clk;
 always #4.1 src_clk=~src_clk;
 always #5.3 rx_clk=~rx_clk;
 reg [31:0] control=0;
 wire [31:0] status;
 reg init=0,start=0,trig=0;
 reg [9:0] seed=7;
 reg [31:0] blank=1024;
 wire fv,lv;wire [191:0] pixels;
 wire initialized,armed,busy;
 gmax3412_pattern #(.WIDTH(W),.HEIGHT(H)) gen0
 (.clk(src_clk),.resetn(resetn),.init_cmd(init),.start_cmd(start),
 .stop_cmd(1'b0),.trigger_cmd(trig),.exposure_cycles(32'd20),.blank_cycles(blank),
 .seed(seed),.initialized(initialized),.armed(armed),.busy(busy),
 .fval(fv),.lval(lv),.data(pixels));
 wire [127:0] data;wire [15:0] keep;wire valid,last;
 reg rxf=0,rxl=0;reg [191:0] rxd=0;
 integer x,y,j;
 reg ready=0,check_data=0;
 integer received=0,framecount=0,tick=0,i,expected;
 reg stalled=0;reg [127:0] held;reg heldlast;
 gmax3412_capture #(.WIDTH(W),.HEIGHT(H)) dut
 (.clk(clk),.resetn(resetn),.control(control),.status(status),
 .emu_clk(src_clk),.emu_fval(fv),.emu_lval(lv),.emu_data(pixels),
 .rx_clk(rx_clk),.rx_fval(rxf),.rx_lval(rxl),.rx_data(rxd),
 .m_axis_tdata(data),.m_axis_tkeep(keep),.m_axis_tvalid(valid),
 .m_axis_tready(ready),.m_axis_tlast(last));
 always @(posedge clk) begin
   if(resetn && check_data) begin
     if(stalled && (!valid || data!==held || last!==heldlast)) $fatal(1,"AXIS stall stability");
     stalled<=valid && !ready;held<=data;heldlast<=last;
     if(valid && ready) begin
       if(keep!==16'hffff) $fatal(1,"TKEEP");
       for(i=0;i<8;i=i+1) begin
         expected=((received+i)%W+(received+i)/W+seed)&1023;
         if(data[i*16 +:16]!==expected[15:0]) $fatal(1,"pixel %0d got %0d expected %0d",received+i,data[i*16 +:16],expected);
       end
       received=received+8;
       if(last !== (received==W*H)) $fatal(1,"TLAST at %0d",received);
       if(last) framecount=framecount+1;
     end
   end else stalled<=0;
 end
 always @(negedge clk) begin
   tick=tick+1;
   if(check_data) ready=(tick%4!=0); // repeatable backpressure
 end
 task pulse_init;begin @(negedge src_clk);init=1;@(negedge src_clk);init=0;wait(initialized);@(negedge src_clk);start=1;@(negedge src_clk);start=0;wait(armed);end endtask
 task trigger;begin @(negedge src_clk);trig=1;@(negedge src_clk);trig=0;end endtask
 task clear_capture;begin @(negedge clk);control=4;repeat(100) @(negedge clk);control=0;repeat(100) @(negedge clk);end endtask
 initial begin
   repeat(20) @(negedge clk);resetn=1;repeat(100) @(negedge clk);
   pulse_init();clear_capture();control=1;wait(status[0]);
   check_data=1;trigger();wait(busy);control=3; // source changes ignored while active
   wait(status[2] && status[6]);
   if(status[5:3]!=0 || status[7] || received!=W*H || framecount!=1) $fatal(1,"frame/status %h",status);
   check_data=0;ready=0;
   clear_capture();control=1;wait(status[0]);blank=1;trigger();
   wait(status[3]); // zero readiness must produce overflow, not silent success
   if(status[2]) $fatal(1,"overflow reported success");
   wait(!busy);clear_capture();blank=1024;seed=991;received=0;
   control=1;wait(status[0]);check_data=1;trigger();wait(status[2] && status[6]);
   if(status[5:3]!=0 || received!=W*H || framecount!=2) $fatal(1,"recovery");
   check_data=0;ready=0;clear_capture();
   // Exercise the physical-source port with synthetic, correctly framed data.
   seed=77;received=0;control=3;wait(status[0]);check_data=1;
   for(y=0;y<H;y=y+1) begin
     for(x=0;x<W;x=x+16) begin
       @(negedge rx_clk);rxf=1;rxl=1;
       for(j=0;j<16;j=j+1) rxd[j*12 +:12]=(x+j+y+seed)&1023;
     end
     @(negedge rx_clk);rxl=0;
     if(y!=H-1) repeat(1024) @(negedge rx_clk);
   end
   @(negedge rx_clk);rxf=0;
   wait(status[2] && status[6]);
   if(status[5:3]!=0 || !status[7] || received!=W*H || framecount!=3) $fatal(1,"physical source mux");
   check_data=0;ready=0;clear_capture();control=3;wait(status[0]);
   repeat(10) begin @(negedge rx_clk);rxf=1;rxl=1;rxd=0;end
   @(negedge rx_clk);rxf=0;rxl=0;
   wait(status[6]);if(!status[4] || status[2]) $fatal(1,"short-frame geometry");
   clear_capture();
   $display("CAPTURE_TEST_PASS: three %0dx%0d frames, both sources, pixel packing, CDC, backpressure, idle-only selection, overflow, geometry and recovery",W,H);
   $finish;
 end
 initial begin #300000000; $fatal(1,"watchdog");end
endmodule
