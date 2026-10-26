`timescale 1ns/1ps
module tb_gmax3412_timing;
 reg clk=0;always #4 clk=~clk;
 reg resetn=0,init=0,start=0,trigger=0;
 reg [31:0] exposure=1,blank=1;
 wire initialized,busy,exposing,fval,lval;
 wire [31:0] seq,exp,lmin,lmax,bmin,bmax,fc,lc;
 gmax3412_pattern source(.clk(clk),.resetn(resetn),.init_cmd(init),.start_cmd(start),
 .stop_cmd(1'b0),.trigger_cmd(trigger),.exposure_cycles(exposure),.blank_cycles(blank),.seed(10'd7),
 .initialized(initialized),.busy(busy),.exposing(exposing),.fval(fval),.lval(lval));
 gmax3412_timing dut(.clk(clk),.resetn(resetn),.exposing(exposing),.fval(fval),.lval(lval),
 .sequence_number(seq),.exposure_cycles(exp),.line_min(lmin),.line_max(lmax),
 .blank_min(bmin),.blank_max(bmax),.frame_cycles(fc),.line_count(lc));
 task frame(input integer e,b,n);
 begin
  @(negedge clk);exposure=e;blank=b;trigger=1;
  @(negedge clk);trigger=0;
  wait(seq==n);@(negedge clk);
  if(exp!=e || lmin!=256 || lmax!=256 || bmin!=b || bmax!=b || lc!=3072 || fc!=3072*256+3071*b)
   $fatal(1,"Timing mismatch e=%d l=%d/%d b=%d/%d fc=%d lc=%d",exp,lmin,lmax,bmin,bmax,fc,lc);
  repeat(20) @(negedge clk);
  if(seq!=n || exp!=e) $fatal(1,"Snapshot not held");
 end endtask
 initial begin
  repeat(5) @(negedge clk);resetn=1;init=1;
  @(negedge clk);init=0;wait(initialized);
  @(negedge clk);start=1;@(negedge clk);start=0;
  frame(1,1,1);frame(120000,256,2);frame(1200000,512,3);
  @(negedge clk);resetn=0;repeat(3) @(negedge clk);
  if(seq!=0 || exp!=0 || fc!=0) $fatal(1,"Reset failed");
  $display("TIMING_TEST_PASS");$finish;
 end
 initial begin #200000000; $fatal(1,"Watchdog");end
endmodule
