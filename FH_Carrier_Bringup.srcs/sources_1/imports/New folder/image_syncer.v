`timescale 1ns / 1ps
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// --Function  : 
//		1. Multi-channel data synchronization, and generate frame/line effective signal;
//		2. Supports up to 12bit
//		3. Supports up to 16chan
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// --History   :
// --Ver       Date         By              Description
// --1.0       2023.02.25   tianjiao.lan    creat
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------


module image_syncer#(
	parameter				DATA_CHAN_NUM	= 16
)
(
	input				clk_rxg,
	input				rst_rxg,
	
	input [DATA_CHAN_NUM*12-1:0]	datain,
	
	input [1:0]			reg_bit_width,		// 0: 12bit; 2: 10bit;
	input				acquisition_start,
	
	output reg			fvalout,
	output reg			lvalout,
	output reg[DATA_CHAN_NUM*12-1:0]dataout		
	
    );
//////////////////////////////////////////////////////////////////////////////////
// 输入信号分组
//////////////////////////////////////////////////////////////////////////////////
	genvar				i;
	wire [11:0]			datain_array[DATA_CHAN_NUM-1:0];
	
	generate
		for (i=0;i<DATA_CHAN_NUM;i=i+1) begin: loopi0
			assign	datain_array[i] = datain[(i+1)*12-1:i*12];
		end
	endgenerate

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// acquisition_start 复位
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	reg					acquisition_start_q;
	reg					acquisition_start_qq;
	reg					acquisition_start_qqq;
	
	reg					rst_acq;
	reg [3:0]			cnt_rst_acq;
	reg					fsm_rst;
	
	always @(posedge clk_rxg) begin
		if (rst_rxg) begin
			acquisition_start_q		<= 0;
			acquisition_start_qq	<= 0;
			acquisition_start_qqq	<= 0;
			rst_acq					<= 0;
			cnt_rst_acq				<= 0;
			fsm_rst					<= 0;
		end
		else begin
			acquisition_start_q		<= acquisition_start;
			acquisition_start_qq	<= acquisition_start_q;
			acquisition_start_qqq	<= acquisition_start_qq;
			
			case (fsm_rst)
				0: begin
					if (acquisition_start_qq == 1 && acquisition_start_qqq == 0) begin
						rst_acq		<= 1;
						fsm_rst		<= 1;
						cnt_rst_acq	<= 0;
					end
				end
				1: begin
					if (cnt_rst_acq == 15) begin
						fsm_rst		<= 0;
						rst_acq		<= 0;
						cnt_rst_acq	<= 0;
					end
					else begin
						cnt_rst_acq	<= cnt_rst_acq + 1;
					end
				end
			endcase
		end
	end
	
	wire				rst_fifo;
	assign	rst_fifo = rst_rxg | rst_acq;
//////////////////////////////////////////////////////////////////////////////////
// 提取各通道参数
//////////////////////////////////////////////////////////////////////////////////
	genvar				j;
	
	wire [DATA_CHAN_NUM-1:0]	fval;
	wire [DATA_CHAN_NUM-1:0]	lval;
	wire [11:0]			data[DATA_CHAN_NUM-1:0];
	reg 				fifo_ren;
	wire [12:0]			fifo_dout[DATA_CHAN_NUM-1:0];
	wire [DATA_CHAN_NUM-1:0]	fifo_empty;
	
	generate
		for (j=0;j< DATA_CHAN_NUM;j=j+1) begin:loopj
			chan_valgen u_chan_valgen(
				.clk				(clk_rxg),
				.rst				(rst_fifo),
									
				.datain				(datain_array[j]),
				.reg_bit_width		(reg_bit_width),
									
				.fvalout			(fval[j]),
				.lvalout			(lval[j]),
				.dataout			(data[j])
			);
			
			FIFO_CCD_W13_D256 u_fifo (
				.clk				(clk_rxg),                  
				.srst				(rst_fifo), 
				
				.wr_en				(fval[j]),              
				.din				({lval[j], data[j]}),                  
				.rd_en				(fifo_ren),              
				.dout				(fifo_dout[j]),    
				
				.full				(),                
				.empty				(fifo_empty[j]),  
				
				.wr_rst_busy		(),  
				.rd_rst_busy		()  
			);
		end
	endgenerate

//////////////////////////////////////////////////////////////////////////////////
// FIFO read
//////////////////////////////////////////////////////////////////////////////////
	reg [1:0]		fsm;
	reg [2:0]		cnt; 

	always @(posedge clk_rxg) begin
		if (rst_rxg) begin
			fsm					<= 0;
			fifo_ren			<= 0;
			cnt					<= 0;
		end
		else begin			
			case (fsm)
				0:	begin
						if (fifo_empty == 0) begin
							fsm		<= 1;
							cnt		<= 0;
						end								
					end
				1:	begin
						if (cnt == 7) begin
							fsm			<= 2;
							fifo_ren	<= 1;
						end
						else begin
							cnt			<= cnt + 1;
						end
					end
				2:	begin
						if (fifo_empty[0] == 1) begin
							fifo_ren	<= 0;
							fsm			<= 0;
						end
					end
			endcase
		end
	end
			
//////////////////////////////////////////////////////////////////////////////////
// output 
//////////////////////////////////////////////////////////////////////////////////
	reg				fvalout_t;
	always @(posedge clk_rxg) begin
		fvalout_t	<= fifo_ren & (~fifo_empty[0]);
		
		fvalout		<= fvalout_t;
		lvalout		<= fifo_dout[0][12] & fvalout_t;
	end
	
	genvar			k;
	
	generate
		for (k=0;k<DATA_CHAN_NUM;k=k+1) begin: loopk
			always @(posedge clk_rxg) begin
				dataout[(k+1)*12-1:k*12]	<= fifo_dout[k][11:0];
			end
		end
	endgenerate
	
endmodule
