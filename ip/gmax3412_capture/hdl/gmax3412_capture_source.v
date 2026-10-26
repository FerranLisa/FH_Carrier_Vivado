`timescale 1ns/1ps
// One frame per request. Unthrottleable input; overflow is fatal for this frame.
module gmax3412_capture_source #(parameter WIDTH=4096, HEIGHT=3072, DEPTH=1024)(
 input wire src_clk, dst_clk, resetn, request,
 input wire fval,lval, input wire [191:0] data,
 output wire [256:0] fifo_data, output wire empty, input wire pop,
 output wire ready, finished, overflow, geometry, dropped
);
 wire req;
 xpm_cdc_single #(.DEST_SYNC_FF(3),.SRC_INPUT_REG(1)) req_cdc
 (.src_clk(dst_clk),.src_in(request & resetn),.dest_clk(src_clk),.dest_out(req));
 wire rst = !req;
 wire full,wr_busy,rd_busy;
 reg [2:0] state=0;
 reg pf=0,pl=0;
 reg [31:0] words=0,line_words=0,lines=0;
 reg ov=0,geo=0,drop=0;
 wire taking = req && !wr_busy && !ov &&
                  ((state==2 && fval && !pf) || state==3);
 wire push = taking && fval && lval && words < WIDTH*HEIGHT/16 && !full;
 wire last = words==WIDTH*HEIGHT/16-1;
 wire [255:0] packed_pixels;
 genvar i;
 generate for(i=0;i<16;i=i+1) begin
   assign packed_pixels[16*i +: 16] = {4'b0,data[12*i +: 12]};
 end endgenerate
 always @(posedge src_clk) begin
   pf<=fval; pl<=lval;
   if(rst) begin
     state<=0;words<=0;line_words<=0;lines<=0;ov<=0;geo<=0;drop<=0;
   end else if(!wr_busy) begin
     case(state)
       0: if(!fval) state<=2;
       2: if(fval && !pf) state<=3;
       3: if(!fval && pf) state<=4;
       4: if(fval && !pf) drop<=1;
       default: state<=0;
     endcase
     if(taking && fval && lval) begin
       if(full) ov<=1;
       words<=words+1;
       line_words<=line_words+1;
       if(words>=WIDTH*HEIGHT/16) geo<=1;
     end
     if(state==3 && pl && !lval) begin
       if(line_words!=WIDTH/16) geo<=1;
       line_words<=0;lines<=lines+1;
     end
     if(state==3 && pf && !fval) begin
       if(words!=WIDTH*HEIGHT/16 || lines+(pl && !lval)!=HEIGHT || lval)
         geo<=1;
     end
     if(lval && !fval) geo<=1;
   end
 end
 wire raw_empty;
 xpm_fifo_async #(.FIFO_MEMORY_TYPE("block"),.FIFO_WRITE_DEPTH(DEPTH),
 .WRITE_DATA_WIDTH(257),.READ_DATA_WIDTH(257),.READ_MODE("fwft"),
 .FIFO_READ_LATENCY(0),.CDC_SYNC_STAGES(3),.DOUT_RESET_VALUE("0"),
 .USE_ADV_FEATURES("0000"),.WR_DATA_COUNT_WIDTH($clog2(DEPTH)+1),
 .RD_DATA_COUNT_WIDTH($clog2(DEPTH)+1)) fifo (
 .rst(rst),.wr_clk(src_clk),.rd_clk(dst_clk),.din({last,packed_pixels}),
 .wr_en(push),.rd_en(pop && !raw_empty && !rd_busy),.dout(fifo_data),
 .full(full),.empty(raw_empty),.wr_rst_busy(wr_busy),.rd_rst_busy(rd_busy),
 .sleep(1'b0),.injectsbiterr(1'b0),.injectdbiterr(1'b0));
 assign empty=raw_empty || rd_busy;
 xpm_cdc_array_single #(.WIDTH(5),.DEST_SYNC_FF(3),.SRC_INPUT_REG(1)) flags_cdc
 (.src_clk(src_clk),.src_in({drop,geo,ov,state==4,state==2 && !wr_busy}),
 .dest_clk(dst_clk),.dest_out({dropped,geometry,overflow,finished,ready}));
endmodule
