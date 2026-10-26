`timescale 1ns / 1ps
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// --Function  : 
//		1. gmax3412_iob_clock -- generate the clock required for training; 
//		2. iserdes1to10_12 -- Instantiate ISERDES1to8 to implement different modes by controlling shifts;
//		3. alignment control, training all channels in sequence;
//		4. according to the number of channels, operate corresponding channels and return training_done signal;
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// --History   :
// --Ver       Date         By              Description
// --1.0       2023.09.11   LTJ             create
// --FH-1      2026.10.02   OpenAI          ZU7EV adaptation, DATAIN_SWAP=0 in wrapper, 10-bit training retained.
// --FH-2      2026.10.02   OpenAI          Reset-domain cleanup: clock module now creates reset for 120 MHz and each
//                                           150 MHz lane domain; per-lane FIFO resets are local to write/read domains.
// --FH-4      2026.10.02   OpenAI          Export the single synchronized 120 MHz reset to the adapter so the same
//                                           reset chain is shared instead of duplicating an async-reset synchronizer.
// --FH-5      2026-10-03   OpenAI          Add V16 diagnostic snapshot of D0/D1 word-alignment candidates, forwarded-clock
//                                           heartbeats, and raw ISERDES sample activity. Snapshot updates can be frozen
//                                           from the AXI GPIO while software reads all candidate slots.
//                                           Fix the pre-existing terminal slot-13 precedence bug so a valid match in
//                                           the last checked candidate is accepted instead of overwritten as failure.
// --FH-6      2026-10-03   OpenAI          V16.1 timing-closure fix: move the diagnostic forwarded-clock heartbeat
//                                           counters from the 600 MHz serial clock domains to their existing /4
//                                           150 MHz CLKDIV domains. This removes fabric counter logic from the
//                                           1.667 ns GMX_A_CLK0/1 timing paths while preserving clock-activity
//                                           observability. No receiver/training functional path is changed.
// --FH-7      2026-10-03   OpenAI          V16.2 CDC/timing-closure fix for the software debug controls.
//                                           debug_freeze is no longer re-synchronized/consumed in training.v;
//                                           the existing gmax3412_rx_adapter synchronizes it once and halts
//                                           automatic retries, eliminating the CDC-11 duplicate-sync fan-out.
//                                           debug_word_index/debug_lane_select now cross into clk_rxg through
//                                           xpm_cdc_array_single. The software already holds these controls
//                                           stable for 10 us before readout, so independent-bit synchronization
//                                           is safe for this debug-only selector. Snapshot capture now follows
//                                           every completed attempt; once the adapter freeze takes effect, no
//                                           new attempt is launched and the last completed snapshot stays stable.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------


module training#(
	parameter			DATA_CHAN_NUM		= 16,			// use to config cmos_data_p/n ports
    parameter           CLK_CHAN_NUM		= 2,    		// use to config cmos_ddr_clk_p/n ports
	parameter			CHN_PORT_WIDTH		= 4,			// use to config reg_chan_num
    parameter           DATAIN_SWAP			= 16'bXXXX_XXXX_XXXX_XXXX 	// LVDS P/N Swap; bit15~bit0 express chan15~chan0
	
)
(
	output								clk_rxg,
    output                              rst_rxg_out,
	input                               reset_n,
		
	input [CLK_CHAN_NUM-1:0]    		cmos_ddr_clk_p,			   
	input [CLK_CHAN_NUM-1:0]    		cmos_ddr_clk_n,			   
	input [DATA_CHAN_NUM-1:0]   		cmos_data_p,           
	input [DATA_CHAN_NUM-1:0]   		cmos_data_n,	
	
	input [1:0]							reg_bit_width,		// 0: 12bit; 2: 10bit; 
	input [CHN_PORT_WIDTH-1:0]			reg_chan_num,		// 8: 16chan;
		
	input [11:0]						training_word,		// 0x98e
	input								cmd_start_training,

    // V16 software-selected snapshot readout. debug_word_index selects one
    // of the actual 14 candidate slots exercised by the existing alignment FSM.
    input [3:0]                         debug_word_index,
    input                               debug_lane_select, // 0=D0, 1=D1
    // Kept in the interface for compatibility with gmax3412_rx_adapter.
    // V16.2 intentionally does not sample this asynchronous signal here.
    // The adapter owns the single clk_rxg-domain synchronizer and retry hold.
    input                               debug_freeze,

	output reg							training_done,
	output reg [DATA_CHAN_NUM-1 :0]		training_result,	// 0:not started or failed; 1: success

    output reg [9:0]                    debug_word,
    output reg                          debug_word_valid,
    output wire                         debug_clk0_activity,
    output wire                         debug_clk1_activity,
    output wire                         debug_lane_activity,

	output [DATA_CHAN_NUM*12-1:0]		dataout				// when 10bit mode, bit9~bit0 effect every chan;
	
    );

/////////////////////////////////////////////////////////
// 时钟模块
/////////////////////////////////////////////////////////
	
	wire               clk_rxio0;
	wire               clk_rxio0_d4;
	wire               clk_rxio1;
	wire               clk_rxio1_d4;
    wire               rst_rxio0_d4;
    wire               rst_rxio1_d4;
    wire               rst_rxg;

	gmax3412_iob_clock u_gmax3412_iob_clock (
        .clk_ddr_p      (cmos_ddr_clk_p),
        .clk_ddr_n      (cmos_ddr_clk_n),
        .reset_n        (reset_n),

        .clk_rxio0      (clk_rxio0),
        .clk_rxio0_d4   (clk_rxio0_d4),
        .clk_rxio1      (clk_rxio1),
        .clk_rxio1_d4   (clk_rxio1_d4),
        .clk_rxg        (clk_rxg),

        .rst_rxio0_d4   (rst_rxio0_d4),
        .rst_rxio1_d4   (rst_rxio1_d4),
        .rst_rxg        (rst_rxg)
	);

    // Shared controller/reset indication for the adapter.
    assign rst_rxg_out = rst_rxg;

//	输入数据同步器
	reg					cmd_start_training_q;
	reg					cmd_start_training_qq;
	reg					cmd_start_training_qqq;
	
	reg [1:0]			reg_bit_width_q,reg_bit_width_qq,reg_bit_width_qqq;
	reg [CHN_PORT_WIDTH:0]		reg_chan_num_q,reg_chan_num_qq,reg_chan_num_qqq;
	
	always @(posedge clk_rxg) begin
        if (rst_rxg) begin
            cmd_start_training_q   <= 1'b0;
            cmd_start_training_qq  <= 1'b0;
            cmd_start_training_qqq <= 1'b0;
            reg_bit_width_q        <= 2'd0;
            reg_bit_width_qq       <= 2'd0;
            reg_bit_width_qqq      <= 2'd0;
            reg_chan_num_q         <= {(CHN_PORT_WIDTH+1){1'b0}};
            reg_chan_num_qq        <= {(CHN_PORT_WIDTH+1){1'b0}};
            reg_chan_num_qqq       <= {(CHN_PORT_WIDTH+1){1'b0}};
        end else begin
            cmd_start_training_q   <= cmd_start_training;
            cmd_start_training_qq  <= cmd_start_training_q;
            cmd_start_training_qqq <= cmd_start_training_qq;
            reg_bit_width_q        <= reg_bit_width;
            reg_bit_width_qq       <= reg_bit_width_q;
            reg_bit_width_qqq      <= reg_bit_width_qq;
            reg_chan_num_q         <= reg_chan_num;
            reg_chan_num_qq        <= reg_chan_num_q;

            if (reg_chan_num_qq == 0)
                reg_chan_num_qqq <= 1;
            else
                reg_chan_num_qqq <= reg_chan_num_qq << 1;
        end
	end
	
/////////////////////////////////////////////////////////
// 总线合并
/////////////////////////////////////////////////////////
	wire [DATA_CHAN_NUM-1:0]		clk_rxio_array;
	wire [DATA_CHAN_NUM-1:0]		clk_rxio_d4_array;
    wire [DATA_CHAN_NUM-1:0]     rst_rxio_d4_array;
	wire [DATA_CHAN_NUM-1:0]		datain_ser_p, datain_ser_n;
	wire [DATA_CHAN_NUM-1:0]		datain_swap;
	wire [11:0]			training_word_real;
	assign training_word_real = (reg_bit_width_qqq == 2) ? {2'd0,training_word[9:0]}:training_word;
	
	assign clk_rxio_array[0]	= clk_rxio0;
	assign clk_rxio_array[1]	= clk_rxio1;
	assign clk_rxio_array[2]	= clk_rxio0;
	assign clk_rxio_array[3]	= clk_rxio1;
	assign clk_rxio_array[4]	= clk_rxio0;
	assign clk_rxio_array[5]	= clk_rxio1;
	assign clk_rxio_array[6]	= clk_rxio0;
	assign clk_rxio_array[7]	= clk_rxio1;
	assign clk_rxio_array[8]	= clk_rxio0;
	assign clk_rxio_array[9]	= clk_rxio1;
	assign clk_rxio_array[10]	= clk_rxio0;
	assign clk_rxio_array[11]	= clk_rxio1;
	assign clk_rxio_array[12]	= clk_rxio0;
	assign clk_rxio_array[13]	= clk_rxio1;
	assign clk_rxio_array[14]	= clk_rxio0;
	assign clk_rxio_array[15]	= clk_rxio1;

	assign clk_rxio_d4_array[0]		= clk_rxio0_d4;
	assign clk_rxio_d4_array[1]		= clk_rxio1_d4;
	assign clk_rxio_d4_array[2]		= clk_rxio0_d4;
	assign clk_rxio_d4_array[3]		= clk_rxio1_d4;
	assign clk_rxio_d4_array[4]		= clk_rxio0_d4;
	assign clk_rxio_d4_array[5]		= clk_rxio1_d4;
	assign clk_rxio_d4_array[6]		= clk_rxio0_d4;
	assign clk_rxio_d4_array[7]		= clk_rxio1_d4;
	assign clk_rxio_d4_array[8]		= clk_rxio0_d4;
	assign clk_rxio_d4_array[9]		= clk_rxio1_d4;
	assign clk_rxio_d4_array[10]	= clk_rxio0_d4;
	assign clk_rxio_d4_array[11]	= clk_rxio1_d4;
	assign clk_rxio_d4_array[12]	= clk_rxio0_d4;
	assign clk_rxio_d4_array[13]	= clk_rxio1_d4;
	assign clk_rxio_d4_array[14]	= clk_rxio0_d4;
	assign clk_rxio_d4_array[15]	= clk_rxio1_d4;

    // Even lanes use CLK_OUT0; odd lanes use CLK_OUT1. Keep the reset paired
    // with the same source-synchronous CLKDIV domain as each lane.
    assign rst_rxio_d4_array[0]  = rst_rxio0_d4;
    assign rst_rxio_d4_array[1]  = rst_rxio1_d4;
    assign rst_rxio_d4_array[2]  = rst_rxio0_d4;
    assign rst_rxio_d4_array[3]  = rst_rxio1_d4;
    assign rst_rxio_d4_array[4]  = rst_rxio0_d4;
    assign rst_rxio_d4_array[5]  = rst_rxio1_d4;
    assign rst_rxio_d4_array[6]  = rst_rxio0_d4;
    assign rst_rxio_d4_array[7]  = rst_rxio1_d4;
    assign rst_rxio_d4_array[8]  = rst_rxio0_d4;
    assign rst_rxio_d4_array[9]  = rst_rxio1_d4;
    assign rst_rxio_d4_array[10] = rst_rxio0_d4;
    assign rst_rxio_d4_array[11] = rst_rxio1_d4;
    assign rst_rxio_d4_array[12] = rst_rxio0_d4;
    assign rst_rxio_d4_array[13] = rst_rxio1_d4;
    assign rst_rxio_d4_array[14] = rst_rxio0_d4;
    assign rst_rxio_d4_array[15] = rst_rxio1_d4;
	
//////////////////////////////////////////////////////////////////////////////////
// 例化ISERDES
//////////////////////////////////////////////////////////////////////////////////
	genvar	i;
	reg [DATA_CHAN_NUM-1:0]		rst_iserdes;
	reg [DATA_CHAN_NUM-1:0]		bitslip;
	reg [DATA_CHAN_NUM-1:0]		idelay_ld;
	reg [8:0]					idelay_valuein[DATA_CHAN_NUM-1:0];
	wire [11:0]					datapar[DATA_CHAN_NUM-1:0];
    wire [DATA_CHAN_NUM-1:0]             raw_activity_lane;
	
	generate
		for (i=0;i<DATA_CHAN_NUM;i=i+1) begin:loopi
			iserdes1to10_12 u_iserdes (
				.clk_rxg            (clk_rxg),
				.clk_rxio           (clk_rxio_array[i]),
				.clk_rxio_d4        (clk_rxio_d4_array[i]),

                .rst_rxg            (rst_rxg),
                .rst_rxio_d4        (rst_rxio_d4_array[i]),
				.rst_iserdes        (rst_iserdes[i]),
				.bitslip			(bitslip[i]), 
				.idelay_ld			(idelay_ld[i]),
				.idelay_valuein		(idelay_valuein[i]),
				
				.reg_bit_width		(reg_bit_width_qqq),
				
				.dataswap			(DATAIN_SWAP[i]), 
				.datain_ser_p		(cmos_data_p[i]), 
				.datain_ser_n		(cmos_data_n[i]), 
				.datapar			(datapar[i]),
                .raw_activity       (raw_activity_lane[i])
			);
			
			//assign dataout[(i+1)+12-1:i*12]	= datapar[i];
		end 
	endgenerate
	
//////////////////////////////////////////////////////////////////////////////////
// Outputs
//////////////////////////////////////////////////////////////////////////////////
	assign dataout	= {			
								datapar[15],
								datapar[14],
								datapar[13],
								datapar[12],
								datapar[11],
								datapar[10],
								datapar[9],
								datapar[8],
								datapar[7],
								datapar[6],
								datapar[5],
								datapar[4],
								datapar[3],
								datapar[2],
								datapar[1],
								datapar[0]
						};
	
//////////////////////////////////////////////////////////////////////////////////
// V16 receive-path observability
//////////////////////////////////////////////////////////////////////////////////

    // Forwarded-clock heartbeat. IMPORTANT: do not put fabric counters on
    // clk_rxio0/1 themselves: those clocks run at 600 MHz (1.667 ns period)
    // and V16's original 8-bit counters created artificial setup violations.
    // The existing CLKDIV clocks are /4 = 150 MHz and are present only when
    // the corresponding forwarded clock/divider chain is alive, so they are
    // the appropriate domains for a low-rate diagnostic heartbeat.
    reg [7:0] dbg_clk0_div;
    reg [7:0] dbg_clk1_div;
    reg       dbg_clk0_toggle;
    reg       dbg_clk1_toggle;

    always @(posedge clk_rxio0_d4) begin
        if (rst_rxio0_d4) begin
            dbg_clk0_div    <= 8'd0;
            dbg_clk0_toggle <= 1'b0;
        end else begin
            dbg_clk0_div <= dbg_clk0_div + 1'b1;
            if (dbg_clk0_div == 8'hFF)
                dbg_clk0_toggle <= ~dbg_clk0_toggle;
        end
    end

    always @(posedge clk_rxio1_d4) begin
        if (rst_rxio1_d4) begin
            dbg_clk1_div    <= 8'd0;
            dbg_clk1_toggle <= 1'b0;
        end else begin
            dbg_clk1_div <= dbg_clk1_div + 1'b1;
            if (dbg_clk1_div == 8'hFF)
                dbg_clk1_toggle <= ~dbg_clk1_toggle;
        end
    end

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] dbg_clk0_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] dbg_clk1_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] dbg_raw0_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] dbg_raw1_sync;
    reg dbg_clk0_last;
    reg dbg_clk1_last;
    reg dbg_clk0_seen;
    reg dbg_clk1_seen;

    // V16.2: synchronize only the debug selector into clk_rxg here.
    //
    // debug_freeze is deliberately NOT synchronized a second time in this
    // module. gmax3412_rx_adapter already owns the single freeze synchronizer
    // and uses its synchronized result to stop automatic retry launches. That
    // removes the CDC-11 condition in which the same AXI-GPIO launch flop fed
    // two independent destination synchronizer chains.
    //
    // The selector is debug-only and firmware holds it stable for 10 us before
    // reading a candidate. At ~120 MHz that is roughly 1200 destination cycles,
    // so xpm_cdc_array_single is appropriate here despite the selector being a
    // multi-bit value: coherency is provided by the stable-source protocol.
    wire [4:0] dbg_select_rxg;
    wire [3:0] dbg_index_qq = dbg_select_rxg[3:0];
    wire       dbg_lane_qq  = dbg_select_rxg[4];

    xpm_cdc_array_single #(
        .DEST_SYNC_FF   (2),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0),
        .WIDTH          (5)
    ) u_xpm_cdc_dbg_select (
        .dest_out (dbg_select_rxg),
        .dest_clk (clk_rxg),
        // SRC_INPUT_REG=0, so src_clk is unused by the XPM. The controls
        // arrive directly from AXI GPIO and are intentionally synchronized
        // only at the destination.
        .src_clk  (1'b0),
        .src_in   ({debug_lane_select, debug_word_index})
    );

    always @(posedge clk_rxg) begin
        if (rst_rxg) begin
            dbg_clk0_sync   <= 2'b00;
            dbg_clk1_sync   <= 2'b00;
            dbg_raw0_sync   <= 2'b00;
            dbg_raw1_sync   <= 2'b00;
            dbg_clk0_last   <= 1'b0;
            dbg_clk1_last   <= 1'b0;
            dbg_clk0_seen   <= 1'b0;
            dbg_clk1_seen   <= 1'b0;
        end else begin
            dbg_clk0_sync <= {dbg_clk0_sync[0], dbg_clk0_toggle};
            dbg_clk1_sync <= {dbg_clk1_sync[0], dbg_clk1_toggle};
            dbg_raw0_sync <= {dbg_raw0_sync[0], raw_activity_lane[0]};
            dbg_raw1_sync <= {dbg_raw1_sync[0], raw_activity_lane[1]};

            if (dbg_clk0_sync[1] != dbg_clk0_last)
                dbg_clk0_seen <= 1'b1;
            if (dbg_clk1_sync[1] != dbg_clk1_last)
                dbg_clk1_seen <= 1'b1;
            dbg_clk0_last <= dbg_clk0_sync[1];
            dbg_clk1_last <= dbg_clk1_sync[1];
        end
    end

    assign debug_clk0_activity = dbg_clk0_seen;
    assign debug_clk1_activity = dbg_clk1_seen;
    assign debug_lane_activity = dbg_lane_qq ? dbg_raw1_sync[1] : dbg_raw0_sync[1];

    // Candidate words are captured at the exact comparison point used by the
    // existing training FSM. Work arrays are updated during an attempt; a
    // complete-attempt snapshot is copied only on training_done rising edge.
    reg [9:0] dbg_work_lane0 [0:13];
    reg [9:0] dbg_work_lane1 [0:13];
    reg [9:0] dbg_snap_lane0 [0:13];
    reg [9:0] dbg_snap_lane1 [0:13];
    reg [13:0] dbg_work_valid0;
    reg [13:0] dbg_work_valid1;
    reg [13:0] dbg_snap_valid0;
    reg [13:0] dbg_snap_valid1;
    reg dbg_training_done_q;
    integer dbg_i;

    always @* begin
        debug_word       = 10'd0;
        debug_word_valid = 1'b0;
        if (dbg_index_qq < 4'd14) begin
            if (dbg_lane_qq == 1'b0) begin
                debug_word       = dbg_snap_lane0[dbg_index_qq];
                debug_word_valid = dbg_snap_valid0[dbg_index_qq];
            end else begin
                debug_word       = dbg_snap_lane1[dbg_index_qq];
                debug_word_valid = dbg_snap_valid1[dbg_index_qq];
            end
        end
    end

//////////////////////////////////////////////////////////////////////////////////
// ALIGNMENT CONTROLLER
// 控制ALIGNMENT模块，顺序依次对所有通道进行training
//////////////////////////////////////////////////////////////////////////////////
	
// ALIGNMENT CONTROLLER
	reg					start_align;
	reg [3:0]			chan_sel;
	reg [1:0]			fsm_align_ctrl;
	localparam			s_CTRL_IDLE 	= 0;
	localparam			s_START_ALIGN 	= 1;
	localparam			s_ALIGN 		= 2;
	reg 				align_done;
	reg 				loc_ok;
	
	always @(posedge clk_rxg) begin
		if (rst_rxg) begin
			fsm_align_ctrl            <= s_CTRL_IDLE;
			training_done             <= 1'b0;
            training_result           <= {DATA_CHAN_NUM{1'b0}};
            start_align               <= 1'b0;
            chan_sel                  <= 4'd0;
		end
		else begin
			start_align					<= 0;
			// FSM
			case (fsm_align_ctrl) 
				s_CTRL_IDLE:		begin
										if (cmd_start_training_qq == 1'b1 && cmd_start_training_qqq == 1'b0) begin
											fsm_align_ctrl		<= s_START_ALIGN;
											chan_sel			<= 0;
											training_done		<= 0;
											training_result		<= 0;
										end
									end
				s_START_ALIGN:		begin
										start_align				<= 1;
										fsm_align_ctrl			<= s_ALIGN;
									end
				s_ALIGN:			begin
										if (align_done == 1) begin
											if (chan_sel == reg_chan_num_qqq - 1) begin
												fsm_align_ctrl	<= s_CTRL_IDLE;
												training_done	<= 1;
											end
											else begin
												chan_sel		<= chan_sel + 1;
												fsm_align_ctrl	<= s_START_ALIGN;
											end
											
											training_result[chan_sel]	<= loc_ok;		// 1 is training OK, 0 is failure
										end
									end
			endcase
		end
	end
//////////////////////////////////////////////////////////////////////////////////
// ALIGNMENT
//////////////////////////////////////////////////////////////////////////////////
	reg [2:0]			fsm_align;
	localparam			s_IDLE			= 0,
						s_RST_ISERDES	= 1,
						s_LD_IDELAY		= 2,
						s_EYE_CHECK		= 3,
						s_EYE_CONFIRM	= 4,
						s_SAMPLE_SET	= 5,
						s_WORD_ALIGN	= 6,
						s_FINISH		= 7;
	
	reg [4:0]			cnt_align;
	reg [8:0]			cnt_steps;
	reg [11:0]			datapar_cur;
	reg [11:0]			datapar_pre;
	reg [511:0]			bit_stable;
	reg 				bit_stable_b_q;
	reg					fsm_edge;
	reg [8:0]			cnt_edge;
	reg [8:0]			edge_s;
	reg [8:0]			edge_e;
	reg [9:0]			edge_sadde;
	reg [1:0]			cnt_bitslip;
	reg [1:0]			cnt_idelay_ld;
	
	always @(posedge clk_rxg) begin
		if (rst_rxg) begin
			fsm_align          <= s_IDLE;
            align_done         <= 1'b0;
            loc_ok             <= 1'b0;
            rst_iserdes        <= {DATA_CHAN_NUM{1'b1}};
            bitslip            <= {DATA_CHAN_NUM{1'b0}};
            idelay_ld          <= {DATA_CHAN_NUM{1'b0}};
            cnt_bitslip        <= 2'd0;
            cnt_idelay_ld      <= 2'd0;
            cnt_align          <= 5'd0;
            cnt_steps          <= 9'd0;
		end
		else begin
			align_done			<= 0;
			
			datapar_cur			<= datapar[chan_sel];
			
			if (cnt_bitslip == 0) begin
				bitslip			<= 0;
			end
			else begin
				cnt_bitslip		<= cnt_bitslip - 1;
			end
			
			if (cnt_idelay_ld == 0) begin
				idelay_ld		<= 0;
			end
			else begin
				cnt_idelay_ld	<= cnt_idelay_ld - 1;
			end
			
			// FSM
			case (fsm_align)
				s_IDLE:	begin
								rst_iserdes						<= 0;
								
								if (start_align == 1) begin
									fsm_align					<= s_RST_ISERDES;
									
									rst_iserdes[chan_sel]		<= 1;
									loc_ok						<= 0;
									cnt_align					<= 31;
								end
						end
				s_RST_ISERDES:	begin
								if (cnt_align == 0) begin
									fsm_align					<= s_LD_IDELAY;
									cnt_steps					<= 0;
									cnt_align					<= 31;
									
									idelay_valuein[chan_sel]	<= 9'd0;
									idelay_ld[chan_sel]			<= 1'b1;
									cnt_idelay_ld				<= 2;
									bit_stable					<= 512'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff;
								end
								else begin
									cnt_align					<= cnt_align - 1;
									
									if (cnt_align == 15) begin
										rst_iserdes[chan_sel]	<= 0;
									end
								end
							end
				s_LD_IDELAY:	begin
								if (cnt_align == 0) begin
									fsm_align					<= s_EYE_CHECK;
									cnt_align					<= 31;
										
									datapar_pre					<= datapar_cur;
									idelay_ld[chan_sel]			<= 1'b1;
									cnt_idelay_ld				<= 2;
								end
								else begin
									cnt_align					<= cnt_align - 1;
								end
							end
				s_EYE_CHECK:	begin
								if (cnt_align == 0) begin
									cnt_align					<= 31;
									if (cnt_steps == 9'd511) begin
										cnt_steps				<= 9'd0;
										fsm_align				<= s_EYE_CONFIRM;
										fsm_edge				<= 0;
										cnt_edge				<= 9'd0;
										edge_s					<= 9'd0;
										edge_e					<= 9'd0;
										edge_sadde				<= 9'd0;
									end
									else begin
										cnt_steps				<= cnt_steps + 9'd1;
										fsm_align				<= s_LD_IDELAY;
										idelay_valuein[chan_sel]<= idelay_valuein[chan_sel] + 9'd1;
									end
									
									if (datapar_cur == datapar_pre) begin
										bit_stable				<= {1'b1, bit_stable[511:1]};
									end			
									else begin			
										bit_stable				<= {1'b0, bit_stable[511:1]};
									end
								end
								else begin
									cnt_align					<= cnt_align - 1;
								end
							end
				s_EYE_CONFIRM:	begin
								bit_stable_b_q					<= bit_stable[cnt_edge];
								
								case (fsm_edge)
									0:	begin
											if (cnt_edge == 9'd511) begin
												fsm_align			<= s_SAMPLE_SET;
												edge_sadde			<= edge_s + edge_e;
											end	
											else begin	
												cnt_edge			<= cnt_edge + 1;
												
												if (cnt_edge >= 1) begin
													if (bit_stable_b_q == 0 && bit_stable[cnt_edge] == 1) begin
														edge_s		<= cnt_edge;
														fsm_edge	<= 1;
													end
												end
												else begin
													if (bit_stable[cnt_edge] == 1) begin
														edge_s		<= 0;
														fsm_edge	<= 1;
													end
												end
											end
										end 
									1: begin
											if (cnt_edge == 9'd511) begin
												fsm_align			<= s_SAMPLE_SET;
												
												if (bit_stable_b_q == 1 && bit_stable[cnt_edge] == 0) begin
													edge_e			<= cnt_edge;
													edge_sadde		<= edge_s + cnt_edge;
												end
											end
											else begin
												cnt_edge			<= cnt_edge + 1;
												
												if (bit_stable_b_q == 1 && bit_stable[cnt_edge] == 0) begin
													if (cnt_edge - edge_s >= 150) begin
														fsm_align	<= s_SAMPLE_SET;
														edge_e		<= cnt_edge;
														edge_sadde	<= edge_s + cnt_edge;
													end
													else begin
														fsm_edge	<= 0;
													end
												end
											end
										end
								endcase
							end
				s_SAMPLE_SET:	begin
								fsm_align				<= s_WORD_ALIGN;
								cnt_align				<= 31;
								idelay_ld[chan_sel]		<= 1'b1;
								cnt_idelay_ld			<= 2;
								
								if (edge_e == 0) begin
									if (edge_s == 0) begin
										idelay_valuein[chan_sel]	<= 9'd256;
									end
									else if (edge_s <= 300) begin
										idelay_valuein[chan_sel]	<= edge_s + 80;
									end
									else begin
										idelay_valuein[chan_sel]	<= edge_s - 230;
									end 
								end
								else begin
									idelay_valuein[chan_sel]		<= edge_sadde[8:1];
								end
							end
				s_WORD_ALIGN:	begin
								if (cnt_align == 0) begin
									if (datapar_cur == training_word_real) begin
										// V16: a match at the terminal candidate (slot 13)
										// must win over the terminal-failure condition.
										fsm_align			<= s_FINISH;
										loc_ok				<= 1;
										cnt_steps			<= 0;
										bitslip[chan_sel]	<= 0;
									end
									else if (cnt_steps == 13) begin
										// All 14 candidates 0..13 were checked with no match.
										fsm_align			<= s_FINISH;
										loc_ok				<= 0;
										cnt_steps			<= 0;
										bitslip[chan_sel]	<= 0;
									end
									else begin
										cnt_steps			<= cnt_steps + 1;
										bitslip[chan_sel]	<= 1;
										cnt_bitslip			<= 2;
									end

									cnt_align				<= 31;
								end	
								else begin		
									cnt_align				<= cnt_align - 1;
								end
							end
				s_FINISH:	begin
								fsm_align					<= s_IDLE;
								align_done					<= 1;
							end
			endcase
		end
	end

	

//////////////////////////////////////////////////////////////////////////////////
// V16 candidate capture / snapshot
//////////////////////////////////////////////////////////////////////////////////
    always @(posedge clk_rxg) begin
        if (rst_rxg) begin
            dbg_work_valid0     <= 14'd0;
            dbg_work_valid1     <= 14'd0;
            dbg_snap_valid0     <= 14'd0;
            dbg_snap_valid1     <= 14'd0;
            dbg_training_done_q <= 1'b0;
            for (dbg_i = 0; dbg_i < 14; dbg_i = dbg_i + 1) begin
                dbg_work_lane0[dbg_i] <= 10'd0;
                dbg_work_lane1[dbg_i] <= 10'd0;
                dbg_snap_lane0[dbg_i] <= 10'd0;
                dbg_snap_lane1[dbg_i] <= 10'd0;
            end
        end else begin
            dbg_training_done_q <= training_done;

            // A new lane pass starts with a fresh validity map.
            if (start_align && (chan_sel == 4'd0))
                dbg_work_valid0 <= 14'd0;
            if (start_align && (chan_sel == 4'd1))
                dbg_work_valid1 <= 14'd0;

            // cnt_steps is the actual candidate index used by s_WORD_ALIGN.
            if ((fsm_align == s_WORD_ALIGN) && (cnt_align == 0) &&
                (cnt_steps < 9'd14)) begin
                if (chan_sel == 4'd0) begin
                    dbg_work_lane0[cnt_steps[3:0]] <= datapar_cur[9:0];
                    dbg_work_valid0[cnt_steps[3:0]] <= 1'b1;
                end else if (chan_sel == 4'd1) begin
                    dbg_work_lane1[cnt_steps[3:0]] <= datapar_cur[9:0];
                    dbg_work_valid1[cnt_steps[3:0]] <= 1'b1;
                end
            end

            // Snapshot after every complete 16-lane training attempt.
            // V16.2 does not sample asynchronous debug_freeze in training.v.
            // The adapter synchronizes freeze once and stops launching retries;
            // an already in-flight attempt may finish and becomes the final
            // stable snapshot. Firmware waits 20 ms after asserting freeze,
            // comfortably longer than the observed attempt time.
            if (training_done && !dbg_training_done_q) begin
                dbg_snap_valid0 <= dbg_work_valid0;
                dbg_snap_valid1 <= dbg_work_valid1;
                for (dbg_i = 0; dbg_i < 14; dbg_i = dbg_i + 1) begin
                    dbg_snap_lane0[dbg_i] <= dbg_work_lane0[dbg_i];
                    dbg_snap_lane1[dbg_i] <= dbg_work_lane1[dbg_i];
                end
            end
        end
    end

endmodule
