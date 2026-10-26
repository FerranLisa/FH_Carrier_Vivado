`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/11/10 18:39:25
// Design Name: 
// Module Name: DDR_TOP
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module DDR_TOP(
	output                             c0_ddr4_act_n   ,
	output [16:0]                      c0_ddr4_adr     ,
	output [1:0]                       c0_ddr4_ba      ,
	output [0:0]                       c0_ddr4_bg      ,
	output [0:0]                       c0_ddr4_cke     ,
	output [0:0]                       c0_ddr4_odt     ,
	output [0:0]                       c0_ddr4_cs_n    ,
	output [0:0]                       c0_ddr4_ck_t    ,
	output [0:0]                       c0_ddr4_ck_c    ,
	output                             c0_ddr4_reset_n ,
	inout [7:0]                       c0_ddr4_dm_dbi_n,
	inout [63:0]                      c0_ddr4_dq      ,
	inout [7:0]                       c0_ddr4_dqs_c   ,
	inout [7:0]                       c0_ddr4_dqs_t   ,               
	
	input                              c0_sys_clk_p,
	input                              c0_sys_clk_n,
	input                              sys_rstn
   );

localparam nCK_PER_CLK                 = 4;
localparam ADDR_WIDTH                  = 28;
localparam MEM_IF_ADDR_BITS            = 29;
localparam PAYLOAD_WIDTH               = 64;
localparam APP_DATA_WIDTH              = 2 * nCK_PER_CLK * PAYLOAD_WIDTH;
localparam APP_MASK_WIDTH              = APP_DATA_WIDTH / 8;
// Wire declarations
wire [MEM_IF_ADDR_BITS-1:0]            app_addr;
wire [2:0]                             app_cmd;
wire                                   app_en;
wire                                   app_rdy;
wire [APP_DATA_WIDTH-1:0]              app_rd_data;
wire                                   app_rd_data_end;
wire                                   app_rd_data_valid;
wire [APP_DATA_WIDTH-1:0]              app_wdf_data;
wire                                   app_wdf_end;
wire [APP_MASK_WIDTH-1:0]              app_wdf_mask;
wire                                   app_wdf_rdy;
wire                                   app_wdf_wren;
wire                                   clk;
wire                                   rst;
wire                                   init_calib_complete;


ddr4_0 u_ddr4
   (
   .sys_rst                    (~sys_rstn                  ),
   .c0_sys_clk_p               (c0_sys_clk_p              ),
   .c0_sys_clk_n               (c0_sys_clk_n              ),
   .c0_ddr4_act_n              (c0_ddr4_act_n             ),
   .c0_ddr4_adr                (c0_ddr4_adr               ),
   .c0_ddr4_ba                 (c0_ddr4_ba                ),
   .c0_ddr4_bg                 (c0_ddr4_bg                ),
   .c0_ddr4_cke                (c0_ddr4_cke               ),
   .c0_ddr4_odt                (c0_ddr4_odt               ),
   .c0_ddr4_cs_n               (c0_ddr4_cs_n              ),
   .c0_ddr4_ck_t               (c0_ddr4_ck_t              ),
   .c0_ddr4_ck_c               (c0_ddr4_ck_c              ),
   .c0_ddr4_reset_n            (c0_ddr4_reset_n           ),
   .c0_ddr4_dm_dbi_n           (c0_ddr4_dm_dbi_n          ),
   .c0_ddr4_dq                 (c0_ddr4_dq                ),
   .c0_ddr4_dqs_c              (c0_ddr4_dqs_c             ),
   .c0_ddr4_dqs_t              (c0_ddr4_dqs_t             ),
   .c0_init_calib_complete     (init_calib_complete       ),
   .c0_ddr4_ui_clk             (clk                   ),
   .c0_ddr4_ui_clk_sync_rst    (rst                       ),
   .dbg_clk                    (                          ),
   .c0_ddr4_app_addr           (app_addr                  ),
   .c0_ddr4_app_cmd            (app_cmd                   ),
   .c0_ddr4_app_en             (app_en                    ),
   .c0_ddr4_app_hi_pri         (1'b0                      ),
   .c0_ddr4_app_wdf_data       (app_wdf_data              ),
   .c0_ddr4_app_wdf_end        (app_wdf_end               ),
   .c0_ddr4_app_wdf_mask       (app_wdf_mask              ),
   .c0_ddr4_app_wdf_wren       (app_wdf_wren              ),
   .c0_ddr4_app_rd_data        (app_rd_data               ),
   .c0_ddr4_app_rd_data_end    (app_rd_data_end           ),
   .c0_ddr4_app_rd_data_valid  (app_rd_data_valid         ),
   .c0_ddr4_app_rdy            (app_rdy                   ),
   .c0_ddr4_app_wdf_rdy        (app_wdf_rdy               ),
   .dbg_bus                    (                          )
   );



//读写测试       
   parameter    [1:0]IDLE  =2'd0;
   parameter    [1:0]WRITE =2'd1;
   parameter    [1:0]WAIT  =2'd2;
   parameter    [1:0]READ  =2'd3;
   parameter    [2:0]CMD_WRITE    =3'd0;
   parameter    [2:0]CMD_READ     =3'd1;
   parameter    TEST_DATA_RANGE   =32'd1000;
   
    reg   [1 :0]state=0;
   reg    [31:0]Count_32=0;
   reg    [ADDR_WIDTH-1:0]app_addr_begin=0;
   
   assign    app_wdf_mask                    =64'h0000_0000_0000_0000;
   assign    app_wdf_end                     =app_wdf_wren;
   assign    app_en                          =(state==WRITE) ? (app_rdy&&app_wdf_rdy) : ((state==READ)&&app_rdy);
   assign    app_wdf_wren                    =(state==WRITE) ? (app_rdy&&app_wdf_rdy) : 1'b0;
   assign    app_cmd                         =(state==WRITE) ? CMD_WRITE : CMD_READ;
   assign    app_addr                        =app_addr_begin;
   assign    app_wdf_data                    ={                                         
                                               Count_32,Count_32,Count_32,Count_32,
                                               Count_32,Count_32,Count_32,Count_32,
                                               Count_32,Count_32,Count_32,Count_32,
                                               Count_32,Count_32,Count_32,Count_32
                                               };
                                               
   always@(posedge clk)
      if(rst&!init_calib_complete)
          begin
          state                           <=IDLE;
          app_addr_begin                  <=29'd0;
          Count_32                        <=32'd0;
          end
   else case(state)
       IDLE:    begin
          state                            <=WRITE;
          Count_32                         <=32'd0;
          app_addr_begin                   <=29'd0;    
         end 
       WRITE:    begin//写DDR4
          state                            <=(Count_32==TEST_DATA_RANGE)&&app_rdy&&app_wdf_rdy ? WAIT:state;//最后一个地址写完之后跳出状态
          Count_32                         <=app_rdy&&app_wdf_rdy?(Count_32+1):Count_32;    
          app_addr_begin                   <=app_rdy&&app_wdf_rdy?(app_addr_begin+29'd8):app_addr_begin;//跳到下一个（8*16=128）bit数据地址
          end
       WAIT:    begin
          state                            <=READ;
          Count_32                         <=32'd0;    
          app_addr_begin                   <=29'd0;    
          end
       READ:    begin//读DDR4
          state                            <=(Count_32==TEST_DATA_RANGE)&&app_rdy? IDLE:state;
          Count_32                         <=app_rdy?(Count_32+1):Count_32;    
          app_addr_begin                   <=app_rdy?(app_addr_begin+29'd8):app_addr_begin;
          end
   default:begin   
          state                            <=IDLE;
          app_addr_begin                   <=29'd0;
          Count_32                         <=32'd0;
          end        
      endcase
   
   (* KEEP = "TRUE" *) reg [511:0]app_rd_data_r;
   (* KEEP = "TRUE" *) reg app_rd_data_valid_r;
   always @(posedge clk) begin
       app_rd_data_r <=  app_rd_data;
       app_rd_data_valid_r <= app_rd_data_valid;
   end
   

   reg     [31:0] count_temp=0;//读计数
   always @(posedge clk) begin
       if(state==WAIT) count_temp <=32'd0;
       else if(app_rd_data_valid_r)  count_temp<= count_temp + 32'b1;
       
    end

   wire [511:0]cm_data;
   assign cm_data = {count_temp,count_temp,count_temp,count_temp,
                     count_temp,count_temp,count_temp,count_temp,
                     count_temp,count_temp,count_temp,count_temp,
                     count_temp,count_temp,count_temp,count_temp   };
   assign tg_compare_error=(app_rd_data_valid_r&&(cm_data!=app_rd_data_r));
   
   
   
   ila_0 degbug_0 (
       .clk(clk), // input wire clk
	   .probe0(cm_data), // input wire [127:0]  probe0  
       .probe1(app_rd_data_r), // input wire [127:0]  probe1 
       .probe2(tg_compare_error), // input wire [0:0]  probe2 
       .probe3(init_calib_complete) // input wire [0:0]  probe3
   );

endmodule
