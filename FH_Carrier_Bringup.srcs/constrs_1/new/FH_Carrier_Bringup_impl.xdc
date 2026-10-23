# V16.3 audit correction, 2026-10-03. Implementation only, PROCESSING_ORDER=LATE.
# Clock waveform, RTL, pins, electrical settings and PCIe constraints preserved.

# V16.3 review: complete clock families and constrain the existing CDC circuits.
# Include every descendant of each primary clock, including /5 and inverted /4.
set_clock_groups -name FH_ASYNC_PL_GMAX_FAMILIES -asynchronous \
    -group [get_clocks -include_generated_clocks clk_pl_0] \
    -group [get_clocks -include_generated_clocks GMX_A_CLK0] \
    -group [get_clocks -include_generated_clocks GMX_A_CLK1]

# Preserve /4 and /5 as related clocks. Only the input to each deliberate
# synchronizer is excepted; all later synchronizer stages remain timed.
set fh_pixel [get_clocks -of_objects [get_pins u_gmax_a_rx/u_training/u_gmax3412_iob_clock/BUFGCE_RXG_DIV5_inst/O]]
set fh_first [get_pins -hier -regexp {u_gmax_a_rx/u_training/loopi\[[0-9]+\]\.u_iserdes/(rst_iserdes_q_reg|bitslip_sync_reg\[0\]|idelay_ld_sync_reg\[0\]|idelay_valuein_q_reg\[[0-9]+\]|reg_bit_width_q_reg\[[0-9]+\])/D}]
set_false_path -from $fh_pixel -to $fh_first

# The custom dual-clock RAM is read only after the Gray write pointer passes
# two synchronization stages and the empty test. Its data does not require
# the next /4-to-/5 phase edge. Bound same-family RAM data propagation to one
# write-clock period; do not except read-address or read-domain logic.
set fh_ramout [get_pins -hier -regexp {u_gmax_a_rx/u_training/loopi\[[0-9]+\]\.u_iserdes/u_fifo/mem_reg.*/(DO[A-Z][0-9]*|O)}]
set fh_dout [get_pins -hier -regexp {u_gmax_a_rx/u_training/loopi\[[0-9]+\]\.u_iserdes/u_fifo/dout_reg\[[0-9]+\]/D}]
set_max_delay -datapath_only 6.668 -from [get_clocks -of_objects [get_pins u_gmax_a_rx/u_training/u_gmax3412_iob_clock/BUFGCE0_DIV_inst/O]] -through $fh_ramout -to $fh_dout


# Per-FIFO Gray pointer skew bounds; unrolled for the XDC command subset.
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[0\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[0\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[0\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[0\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[1\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[1\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[1\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[1\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[2\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[2\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[2\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[2\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[3\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[3\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[3\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[3\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[4\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[4\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[4\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[4\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[5\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[5\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[5\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[5\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[6\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[6\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[6\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[6\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[7\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[7\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[7\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[7\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[8\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[8\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[8\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[8\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[9\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[9\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[9\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[9\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[10\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[10\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[10\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[10\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[11\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[11\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[11\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[11\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[12\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[12\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[12\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[12\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[13\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[13\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[13\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[13\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[14\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[14\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[14\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[14\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[15\]\.u_iserdes/u_fifo/(wr_gray_reg\[[0-4]\]|wr_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[15\]\.u_iserdes/u_fifo/u_sync_wr_gray_to_rd/syncstages_ff_reg\[0\]\[[0-9]+\]}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[15\]\.u_iserdes/u_fifo/(rd_gray_reg\[[0-4]\]|rd_bin_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[15\]\.u_iserdes/u_fifo/u_sync_rd_gray_to_wr/syncstages_ff_reg\[0\]\[[0-9]+\]}]

# Bound IDELAY data/load arrival spread below the extra destination pipeline delay.
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[0\]\[[0-9]+\]|idelay_ld_reg\[0\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[0\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[1\]\[[0-9]+\]|idelay_ld_reg\[1\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[1\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[2\]\[[0-9]+\]|idelay_ld_reg\[2\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[2\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[3\]\[[0-9]+\]|idelay_ld_reg\[3\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[3\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[4\]\[[0-9]+\]|idelay_ld_reg\[4\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[4\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[5\]\[[0-9]+\]|idelay_ld_reg\[5\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[5\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[6\]\[[0-9]+\]|idelay_ld_reg\[6\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[6\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[7\]\[[0-9]+\]|idelay_ld_reg\[7\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[7\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[8\]\[[0-9]+\]|idelay_ld_reg\[8\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[8\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[9\]\[[0-9]+\]|idelay_ld_reg\[9\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[9\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[10\]\[[0-9]+\]|idelay_ld_reg\[10\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[10\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[11\]\[[0-9]+\]|idelay_ld_reg\[11\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[11\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[12\]\[[0-9]+\]|idelay_ld_reg\[12\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[12\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[13\]\[[0-9]+\]|idelay_ld_reg\[13\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[13\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[14\]\[[0-9]+\]|idelay_ld_reg\[14\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[14\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]
set_bus_skew 6.668 -from [get_cells -hier -regexp {u_gmax_a_rx/u_training/(idelay_valuein_reg\[15\]\[[0-9]+\]|idelay_ld_reg\[15\])}] -to [get_cells -hier -regexp {u_gmax_a_rx/u_training/loopi\[15\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])}]

# ---------------------------------------------------------------------------
# PCIe reference-clock monitor
# ---------------------------------------------------------------------------
# M2_PCIE_REFCLK_SOM_100M is the primary 100 MHz PCIe reference clock.
# Vivado automatically derives the monitor clock at the IBUFDS_GTE4 ODIV2 pin.
# Rename that auto-derived clock at its point of origin using the rename-only
# form of create_generated_clock.  Because no -divide_by/-edges/etc. options
# are supplied, this does not create a different waveform; it only gives the
# existing derived clock a stable user-defined name.
create_generated_clock -name FH_PCIE_REFCLK_ODIV2_50M \
    [get_pins {u_design_1_wrapper/design_1_i/fh_pcie_refclk_monit_0/inst/u_ibufds_gte4_pcie_refclk/ODIV2}]

# The 100 MHz primary and 50 MHz derivative remain related within one group.
# The complete PCIe reference-clock family is asynchronous to clk_pl_0.
set_clock_groups -name FH_ASYNC_PL_PCIE_REFCLK_FAMILY -asynchronous \
    -group [get_clocks {clk_pl_0}] \
    -group [get_clocks {M2_PCIE_REFCLK_SOM_100M FH_PCIE_REFCLK_ODIV2_50M}]

# sys_resetn is generated in the clk_pl_0 domain and intentionally drives the
# asynchronous assertion input of the first 50 MHz reset synchronizer stage.
# Deassertion is synchronized by the following stage.  Exclude only that first
# asynchronous CLR endpoint from recovery/removal timing.
set_false_path -to [get_pins -hierarchical -regexp {.*fh_pcie_refclk_monit_0.*/rst50_sync_reg\[0\]/CLR}]
