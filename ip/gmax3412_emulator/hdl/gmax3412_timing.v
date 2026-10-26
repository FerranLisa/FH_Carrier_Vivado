`timescale 1ns/1ps
// Passive measurements of source signals, in source-clock cycles. Snapshot is
// committed at FVAL falling edge and held until the next completed frame.
module gmax3412_timing(
 input wire clk,resetn,exposing,fval,lval,
 output reg [31:0] sequence_number,exposure_cycles,line_min,line_max,
 output reg [31:0] blank_min,blank_max,frame_cycles,line_count
);
 reg pe,pf,pl;
 reg [31:0] ticks,exposure_start,line_start,line_end,frame_start;
 reg [31:0] exp_work,lmin,lmax,bmin,bmax,lines;
 reg have_line;
 wire [31:0] width_now=ticks-line_start;
 wire [31:0] blank_now=ticks-line_end;
 always @(posedge clk) begin
  if(!resetn) begin
   pe<=0;pf<=0;pl<=0;ticks<=0;exposure_start<=0;line_start<=0;line_end<=0;frame_start<=0;
   exp_work<=0;lmin<=32'hffffffff;lmax<=0;bmin<=32'hffffffff;bmax<=0;lines<=0;have_line<=0;
   sequence_number<=0;exposure_cycles<=0;line_min<=0;line_max<=0;
   blank_min<=0;blank_max<=0;frame_cycles<=0;line_count<=0;
  end else begin
   ticks<=ticks+1;pe<=exposing;pf<=fval;pl<=lval;
   if(exposing && !pe) exposure_start<=ticks;
   if(!exposing && pe) exp_work<=ticks-exposure_start;
   if(fval && !pf) begin
    frame_start<=ticks;lmin<=32'hffffffff;lmax<=0;
    bmin<=32'hffffffff;bmax<=0;lines<=0;have_line<=0;
   end
   if(fval && lval && !pl) begin
    line_start<=ticks;
    if(have_line && pf) begin
     if(blank_now<bmin) bmin<=blank_now;
     if(blank_now>bmax) bmax<=blank_now;
    end
   end
   if(!lval && pl) begin
    line_end<=ticks;have_line<=1;lines<=lines+1;
    if(width_now<lmin) lmin<=width_now;
    if(width_now>lmax) lmax<=width_now;
   end
   if(!fval && pf) begin
    sequence_number<=sequence_number+1;exposure_cycles<=exp_work;
    line_min<=(!lval && pl && width_now<lmin) ? width_now:lmin;
    line_max<=(!lval && pl && width_now>lmax) ? width_now:lmax;
    blank_min<=bmin;blank_max<=bmax;
    frame_cycles<=ticks-frame_start;line_count<=lines+(!lval && pl);
   end
  end
 end
endmodule
