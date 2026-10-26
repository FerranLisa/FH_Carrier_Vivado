`timescale 1ns / 1ps
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// --Function  : 	
//		1. training-- data alignment; 
//		2. image_syncer -- detects synchronization code and generates valid signal of frame/line/data_val; 
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// --History   :
// --Ver       Date         By              Description
// --1.0       2023.09.07   LTJ    			create
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------



module cmos_image_receiver#(
	parameter				DATA_CHAN_NUM		= 16,
    parameter           	CLK_CHAN_NUM		= 2,    					// use to config cmos_ddr_clk_p/n ports
	parameter				CHN_PORT_WIDTH		= 4,	
    parameter           	DATAIN_SWAP			= 16'bXXXX_XXXX_XXXX_XXXX 	// LVDS P/N Swap
	
)
(
	input								clk_rxg,
	input								rst_rxg,
	
	input [CLK_CHAN_NUM-1:0]    		cmos_ddr_clk_p,		   
	input [CLK_CHAN_NUM-1:0]    		cmos_ddr_clk_n,		   
	input [DATA_CHAN_NUM-1:0]   		cmos_data_p,           
	input [DATA_CHAN_NUM-1:0]   		cmos_data_n,	
	
	input [1:0]							reg_bit_width,			// 0: 12bit; 2: 10bit; 
	input [CHN_PORT_WIDTH-1:0]			reg_chan_num,			// 8: 16chan;
	input								acquisition_start,
		
	input [11:0]						training_word,		
	input								cmd_start_training,
	output 								training_done,
	output [DATA_CHAN_NUM-1 :0]			training_result,
	
	output								fvalout,
	output								lvalout,
	output [DATA_CHAN_NUM*12-1:0]		dataout
		
    );
	
///////////////////////////////////////////////
// training module
//////////////////////////////////////////////
	wire [DATA_CHAN_NUM*12-1:0]			data_train;
	
	training#(
		.DATA_CHAN_NUM		(DATA_CHAN_NUM),
	    .CLK_CHAN_NUM		(CLK_CHAN_NUM),		
	    .CHN_PORT_WIDTH		(CHN_PORT_WIDTH),		
	    .DATAIN_SWAP		(DATAIN_SWAP)			
	)
	u_training(
		.clk_rxg			(clk_rxg),
		.rst_rxg			(rst_rxg),
		                    
		.cmos_ddr_clk_p		(cmos_ddr_clk_p),		
	    .cmos_ddr_clk_n		(cmos_ddr_clk_n),		
	    .cmos_data_p		(cmos_data_p),        
	    .cmos_data_n		(cmos_data_n),	
	                        
	    .reg_bit_width		(reg_bit_width),		
	    .reg_chan_num		(reg_chan_num),		
	                        
	    .training_word		(training_word),		
	    .cmd_start_training	(cmd_start_training),
	    .training_done		(training_done),
	    .training_result	(training_result),
	                        
	    .dataout            (data_train)
	);

///////////////////////////////////////////////
// image_syncer module
//////////////////////////////////////////////

	image_syncer#(
		.DATA_CHAN_NUM		(DATA_CHAN_NUM)
	)
	u_image_syncer
	(
		.clk_rxg			(clk_rxg),	
		.rst_rxg			(rst_rxg),
		
		.datain				(data_train),
		.acquisition_start	(acquisition_start),
		
		.reg_bit_width		(reg_bit_width),
	    
	    .fvalout			(fvalout),
	    .lvalout			(lvalout),
	    .dataout			(dataout)	
	);
	
endmodule
