/*
 * FH_Carrier Prototype Bring-Up
 * PZ-ZU7EV / Cortex-A53_0
 *
 * Revision: GMAX3412 timing and recovery qualification (v21; V16.3 receiver)
 *
 * Version history:
 *   v21 (24 October 2026): Q adds 337 verified repeated captures and exact
 *     hardware exposure/line/blank/frame timing checks; requires Timing BIT.
 *   v20 (24 October 2026): T adds stress, timing, overflow and recovery tests.
 *
 *   v19 (24 October 2026):
 *     - Adds D: three emulator-to-DDR captures via AXI DMA, pixel-by-pixel
 *       verification, cache maintenance, guard regions, timeouts and cleanup.
 *     - Requires the capture BIT/XSA and its initialized PS HP0 DDR interface.
 *     - Retains all v18 tests; reserves an aligned 24 MiB DDR frame buffer.
 *
 *   v18 (24 October 2026):
 *     - Adds main-menu option 9: gmax3412_emulator smoke test at 0xA0030000.
 *     - Verifies one 4096 x 3072 frame, checksum, trigger/error counters,
 *       configuration readback and final disarm, with bounded polling.
 *     - Preserves all v17 diagnostics; emulator test is manual only.
 *
 *   v5:
 *     - Initial complete SATA/USB3/PCIe reference-clock diagnostics.
 *     - USB3 PASS/FAIL still used PS-GTR lane-1 PLL status FD4063E4.
 *
 *   v6:
 *     - Removed FD4063E4 as a USB3 PASS/FAIL criterion after Vivado IBERT
 *       proved USB0 Linked (U0) while FD4063E4 remained 0x00000001.
 *     - Added the minimal AMD IBERT helper update to USB3 GCTL at 0xFE20C110.
 *     - Added USB3 functional validation through GDBGLTSSM at 0xFE20C164
 *       and recognition of valid SuperSpeed U-states, including direct U0.
 *     - USB3 PORTSC is intentionally not used because this diagnostic does
 *       not perform xHCI enumeration.
 *
 *   v6_fixed:
 *     - Removed platform.h, init_platform(), and cleanup_platform() because
 *       the current Vitis 2025.2 standalone BSP does not provide platform.h.
 *
 *   v7:
 *     - Consolidated the version history in this source file for traceability.
 *     - Corrected the final diagnostic note to say firmware cannot measure
 *       differential amplitude, common-mode voltage, duty cycle, edge rates
 *       or jitter.
 *     - No functional diagnostic logic changes relative to v6_fixed.
 *
 *   v8:
 *     - Removed interactive menu option 2 (EEPROM quick read) and option 7
 *       (PAC1944 I2C1 ILA capture pattern); numbering of the remaining options
 *       is intentionally preserved for traceability with earlier bring-up logs.
 *     - Runs the complete SATA/USB3/PCIe reference-clock diagnostics
 *       automatically during start-up before the interactive menu is shown.
 *     - Adds SATA 150 MHz, USB3 100 MHz, USB3 SuperSpeed link, and PCIe
 *       100 MHz results to the START-UP DIAGNOSTIC SUMMARY table.
 *     - Option 9 remains available to re-run the clock diagnostics manually.
 *     - No changes to the validated v7 clock-diagnostic algorithms.
 *
 *   v9:
 *     - Renumbered all numeric interactive commands consecutively from 1 to 7.
 *     - EEPROM full dump moved 3 -> 2; EUI-48 moved 4 -> 3; PAC1944 ID
 *       moved 5 -> 4; PAC1944 rail measurements moved 6 -> 5.
 *     - Complete start-up diagnostics moved 8 -> 6 and complete reference-clock
 *       diagnostics moved 9 -> 7.
 *     - No diagnostic logic changes relative to v8; start-up still runs the
 *       complete clock analysis automatically before the menu is shown.
 *
 *   v10:
 *     - Added FH_Sen4K / GMAX3412-A control through the new dual AXI GPIO.
 *     - Added safe camera-board power-up/power-down sequencing for PWR_EN,
 *       SYS_RST_N and the local 40 MHz oscillator enable (CLK_EN).
 *     - Added GMAX3412 I2C diagnostics through dedicated AXI IIC, including
 *       safe register reads and a same-value write/readback test.
 *     - Added bit-banged GMAX3412 SPI read/write diagnostics through AXI GPIO.
 *       SPI testing only touches SDO_TDIG_SEL (forcing bit1=0 if required for
 *       SDO operation); no imaging/timing register is modified.
 *     - Added an FH_Sen4K submenu as main-menu option 8. No sensor power-up is
 *       performed automatically at application start; GPIO is only forced to
 *       a SAFE/OFF I2C state.
 *     - Sensor streaming, internal PWR_UP_EN/CH_CLK_EN and image acquisition
 *       are intentionally NOT started by this revision.
 *
 *   v11:
 *     - Preserves every validated v10 low-speed control/I2C/SPI diagnostic.
 *     - Adds the complete Gpixel Datasheet V1.0 Table 17 recommended register
 *       map for 10-bit, 16-channel, 1.28-Gb/s Sub-LVDS with x1 PGA gain.
 *       The two D_TEMP table placeholders (I2C 0x3257/0x3258) are read-only
 *       temperature outputs and are intentionally not written.
 *     - Adds controlled register-map upload with key-register readback.
 *     - Adds the documented internal sequence: CLK_STABLE_EN, >=5 ms,
 *       PWR_UP_EN, >=80 ms, CH_CLK_EN, >=1 ms, then the six-step Sub-LVDS
 *       PHY calibration using I2C registers 0x3023/0x3024.
 *     - STREAM_EN remains OFF after configuration/internal power-up. Enabling
 *       high-speed Sub-LVDS output is a separate, explicitly confirmed action.
 *     - Adds a one-shot TEXP1 frame-request pulse after streaming is enabled.
 *     - Adds graceful GMAX internal power-down before external FH_Sen4K off.
 *     - Corrects AXI GPIO TRI reporting: channels configured with fixed
 *       direction in the IP may read TRI as all ones; DATA/physical behavior
 *       is the relevant validation.
 *
 *   v12:
 *     - Changes the GMAX3412 high-speed operating point from Table 17
 *       (10-bit / 1.28 Gb/s) to the Datasheet V1.0 Table 16 recommended
 *       register map for 10-bit / 1.20 Gb/s Sub-LVDS with x1 PGA gain.
 *     - This matches the ZU7EV -2 ISERDESE3 pulse-width capability observed
 *       during routed timing analysis: 600 MHz DDR clock instead of 640 MHz.
 *     - Table 16 contains 532 address entries; the two D_TEMP placeholders
 *       at I2C 0x3257/0x3258 remain read-only and are omitted, leaving
 *       530 configuration writes.
 *     - The training pattern remains 10'h165 (0x3015:0x3014 = 0x01:0x65).
 *
 *   v13:
 *     - Rebased the GMAX_A software interface on the current Vitis 2025.2
 *       SDT-generated xparameters.h: AXI GPIO GMAX_A at 0xA0010000 and
 *       AXI IIC GMAX_A at 0xA0020000.
 *     - Added XIic driver-configuration validation with SDT base-address
 *       lookup and XIic_CfgInitialize, while retaining the validated
 *       low-level XIic_Send/XIic_Recv polled transfers.
 *     - Added controller recovery after failed repeated-start/read/write
 *       transactions so a failed probe does not leave AXI IIC wedged busy.
 *     - Added submenu command I: a read-only basic I2C probe that performs
 *       the safe external FH_Sen4K power/reset/40-MHz sequence if needed,
 *       then reads 0x2E00 and decodes CLK_STABLE_EN / STREAM_EN. It performs
 *       no GMAX register writes and does not enable internal power or stream.
 *     - Preserves the complete v12 Table-16 10-bit/1.20-Gb/s configuration,
 *       internal power-up, PHY calibration, stream and TEXP frame-request
 *       behavior unchanged.
 *
 *   v14:
 *     - Matches the revised axi_gpio_gmax_a_ctrl channel 2 width of 18 bits.
 *       CH2[0] remains SDO_TDIG, CH2[16:1] carries
 *       gmax_a_training_result[15:0], and CH2[17] carries
 *       gmax_a_training_done from gmax3412_rx_adapter.
 *     - Sets all 18 channel-2 GPIO bits to input direction during safe PL
 *       initialization, preserving SPI SDO operation while exposing receiver
 *       status to the Cortex-A53.
 *     - Adds submenu command T to read/decode PL receiver training status,
 *       including per-lane failures.
 *     - STREAM_EN command S now waits up to 2 s for the automatic/retry
 *       receiver trainer to report training_done=1 and training_result=0xFFFF.
 *       A partial/failed attempt is not treated as final because the RTL
 *       automatically retries until all 16 lanes pass.
 *     - Removes the obsolete runtime warning about unconfirmed differential
 *       termination; the current FH_Carrier XDC already applies TERM_100 to
 *       all 16 GMAX data inputs and both forwarded clock inputs.
 *
 *   v15:
 *     - Increases receiver-training observability without changing Vivado or
 *       sensor configuration. AXI GPIO CH2 is polled every 10 us instead of
 *       every 10 ms so the software can observe the finite training_done
 *       interval between automatic retry attempts.
 *     - Records completed training attempts in RAM during the 2 s observation
 *       window instead of printing from inside the fast polling loop. This
 *       avoids UART traffic perturbing/masking short receiver-status events.
 *     - Reports number of completed attempts observed, each captured result
 *       mask, best completed result, best result observed while an attempt was
 *       still running, and the specific lanes not passing.
 *     - Distinguishes 'no completed attempt observed' from repeated completed
 *       attempts with partial lane lock, which separates receive-clock/FSM
 *       problems from lane/alignment problems before further RTL changes.
 *
 *   v16:
 *     - Expands GMAX AXI GPIO channel 1 to 15 bits and channel 2 to 32 bits.
 *       Existing control/training mappings are preserved in bits 0..17.
 *     - Adds a software-selectable D0/D1 snapshot of the actual 14 word-alignment
 *       candidate slots exercised by training.v. Snapshots are taken only after
 *       a complete 16-lane training attempt and can be frozen during readout.
 *     - Adds sticky activity indicators for both forwarded clocks and for the
 *       selected lane's pre-word-alignment ISERDESE3 sample stream.
 *     - Adds readback of 0x2E00, 0x3000, 0x3010, 0x3014 and 0x3015 so the
 *       sensor output mode, bit order and 10-bit training word are verified
 *       immediately beside the PL receive-path diagnosis.
 *     - Adds submenu command D for the raw D0/D1 receiver diagnostic and runs
 *       the same diagnostic automatically when command S times out.
 *     - Fixes the existing training.v terminal-candidate precedence bug: a
 *       valid match in slot 13 is no longer overwritten by the terminal fail.
 *     - No image capture is attempted until normal 16-lane training reaches
 *       0xFFFF. Existing power, I2C, SPI and Table-16 behavior is preserved.
 *
 *   v17:
 *     - Adds submenu P: verified TP=0x000 / 0x3FF with ILA capture pauses.
 *       STREAM_EN is cleared before TP writes. Full original TP bytes,
 *       CLK/STREAM byte and RX debug-freeze state are restored on completion
 *       or abort; the high TP byte's reserved upper nibble is preserved.
 *     - Failed restoration blocks stream/frame/pulse tests until successful
 *       A initialization. No FPGA, PHY, output-mode or Table-16 changes.
 *     - Updates the application banners to v17.
 *
 * Interactive options retained:
 *   1 - Power-good
 *   2 - EEPROM full dump
 *   3 - EUI-48
 *   4 - PAC1944 identification over PS I2C1/EMIO
 *   5 - PAC1944 rail measurements
 *   6 - Re-run complete start-up diagnostics (includes clock diagnostics)
 *   7 - Differential reference clocks
 *   8 - FH_Sen4K / GMAX3412-A diagnostics
 *   R - External reset test
 *
 * Reference-clock test strategy:
 *   M2_SATA_REFCLK_150M:
 *     PS-GTR Bank 505 REFCLK0, lane 0.
 *     Checks protocol assignment, configured REFCLK frequency/mux, PLL
 *     acquisition state, and SATA PxSSTS link state.
 *
 *   USB3_CLK100:
 *     PS-GTR Bank 505 REFCLK1, lane 1.
 *     Checks protocol assignment and configured REFCLK frequency/mux.
 *     Lane-1 PLL_STATUS_READ_1 is printed for diagnosis only because a
 *     proven USB3 U0 link was observed while that register remained 0x01.
 *     The test then applies the same minimal GCTL update used by AMD's
 *     IBERT FSBL helper and checks the DWC3 GDBGLTSSM SuperSpeed state.
 *
 *   M2_PCIE_REFCLK_SOM:
 *     PL GTH Bank 223 MGTREFCLK0 -> fh_pcie_refclk_monitor.v measures the
 *     actual differential-clock frequency and exposes the count/status through
 *     a dual-channel AXI GPIO named "axi_gpio_clkmon".
 *
 * IMPORTANT:
 *   SATA lane 0 still uses the PS-GTR PLL status as supporting evidence.
 *   USB3 lane 1 does NOT use FD4063E4 as a PASS/FAIL criterion: on this
 *   hardware Vivado IBERT proved USB0 Linked (U0) while FD4063E4 remained
 *   0x00000001. USB3 is therefore classified from static PS-GTR configuration
 *   plus the DWC3 SuperSpeed debug state after the minimal IBERT GCTL update.
 */

#include "xil_printf.h"
#include "xstatus.h"
#include "xparameters.h"
#include "xgpiops.h"
#include "xiicps.h"
#include "xiicps_hw.h"
#include "xiic.h"
#include "xiic_l.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xil_types.h"
#include "sleep.h"
#include <stddef.h>

#define PG_3V3_PIN             39U
#define PG_5V_PIN              40U
#define PG_1V8_PIN             41U

#define EEPROM_ADDR            0x50U
#define EEPROM_SIZE            256U
#define EEPROM_DUMP_LINE       16U
#define EEPROM_I2C_FREQ_HZ     100000U

#define PAC1944_ADDR           0x10U
#define PAC1944_I2C_FREQ_HZ    100000U
#define I2C_IDLE_TIMEOUT_US    100000U

/* Zynq UltraScale+ MPSoC CRL_APB diagnostics. */
#ifdef XPAR_PSU_CRL_APB_S_AXI_BASEADDR
#define FH_CRL_APB_BASEADDR        ((UINTPTR)XPAR_PSU_CRL_APB_S_AXI_BASEADDR)
#else
#define FH_CRL_APB_BASEADDR        ((UINTPTR)0xFF5E0000U)
#endif

#define FH_CRL_I2C0_REF_CTRL       (FH_CRL_APB_BASEADDR + 0x120U)
#define FH_CRL_I2C1_REF_CTRL       (FH_CRL_APB_BASEADDR + 0x124U)
#define FH_CRL_RST_LPD_IOU2        (FH_CRL_APB_BASEADDR + 0x238U)
#define FH_I2C_REF_CLKACT_MASK     0x01000000U
#define FH_I2C0_RESET_MASK         0x00000200U
#define FH_I2C1_RESET_MASK         0x00000400U

/* Run the destructive XIicPs self-test during start-up diagnostics. */
#define FH_DIAG_RUN_I2C1_SELFTEST  1U

#define PAC_REG_VBUS1          0x07U
#define PAC_REG_VBUS2          0x08U
#define PAC_REG_VBUS3          0x09U
#define PAC_REG_VBUS4          0x0AU

#define PAC_REG_VSENSE1        0x0BU
#define PAC_REG_VSENSE2        0x0CU
#define PAC_REG_VSENSE3        0x0DU
#define PAC_REG_VSENSE4        0x0EU

#define PAC_REG_REFRESH_V      0x1FU
#define PAC_REG_NEG_PWR_ACT    0x22U

#define PAC_REG_PID            0xFDU
#define PAC_REG_MID            0xFEU
#define PAC_REG_REV            0xFFU


/* ------------------------------------------------------------------------- */
/* FH_Sen4K / GMAX3412-A PL control and serial interfaces                    */
/* ------------------------------------------------------------------------- */

/*
 * AXI GPIO instance used for GMAX_A controls.
 * Prefer the instance-specific symbol generated from the Vivado BD, then
 * canonical XGpio aliases.  The current design also contains axi_gpio_clkmon
 * as XGPIO_0, so the GMAX GPIO is normally XGPIO_1.
 */
#if defined(XPAR_AXI_GPIO_GMAX_A_CTRL_BASEADDR)
#define FH_GMAX_GPIO_AVAILABLE       1
#define FH_GMAX_GPIO_BASEADDR        ((UINTPTR)XPAR_AXI_GPIO_GMAX_A_CTRL_BASEADDR)
#elif defined(XPAR_AXI_GPIO_GMAX_A_CTRL_0_BASEADDR)
#define FH_GMAX_GPIO_AVAILABLE       1
#define FH_GMAX_GPIO_BASEADDR        ((UINTPTR)XPAR_AXI_GPIO_GMAX_A_CTRL_0_BASEADDR)
#elif defined(XPAR_XGPIO_1_BASEADDR)
#define FH_GMAX_GPIO_AVAILABLE       1
#define FH_GMAX_GPIO_BASEADDR        ((UINTPTR)XPAR_XGPIO_1_BASEADDR)
#elif defined(XPAR_AXI_GPIO_1_BASEADDR)
#define FH_GMAX_GPIO_AVAILABLE       1
#define FH_GMAX_GPIO_BASEADDR        ((UINTPTR)XPAR_AXI_GPIO_1_BASEADDR)
#else
#define FH_GMAX_GPIO_AVAILABLE       0
#define FH_GMAX_GPIO_BASEADDR        ((UINTPTR)0U)
#endif

/*
 * Dedicated AXI IIC for GMX_A_I2C_SCL/SDA.
 * There is currently only one AXI-IIC instance in FH_Carrier_Bringup.
 */
#if defined(XPAR_AXI_IIC_GMAX_A_BASEADDR)
#define FH_GMAX_IIC_AVAILABLE        1
#define FH_GMAX_IIC_BASEADDR         ((UINTPTR)XPAR_AXI_IIC_GMAX_A_BASEADDR)
#elif defined(XPAR_AXI_IIC_GMAX_A_0_BASEADDR)
#define FH_GMAX_IIC_AVAILABLE        1
#define FH_GMAX_IIC_BASEADDR         ((UINTPTR)XPAR_AXI_IIC_GMAX_A_0_BASEADDR)
#elif defined(XPAR_XIIC_0_BASEADDR)
#define FH_GMAX_IIC_AVAILABLE        1
#define FH_GMAX_IIC_BASEADDR         ((UINTPTR)XPAR_XIIC_0_BASEADDR)
#elif defined(XPAR_AXI_IIC_0_BASEADDR)
#define FH_GMAX_IIC_AVAILABLE        1
#define FH_GMAX_IIC_BASEADDR         ((UINTPTR)XPAR_AXI_IIC_0_BASEADDR)
#else
#define FH_GMAX_IIC_AVAILABLE        0
#define FH_GMAX_IIC_BASEADDR         ((UINTPTR)0U)
#endif

/* Current exported hardware map; mismatches are reported, not fatal. */
#define FH_GMAX_GPIO_EXPECTED_BASEADDR  ((UINTPTR)0xA0010000U)
#define FH_GMAX_IIC_EXPECTED_BASEADDR   ((UINTPTR)0xA0020000U)

/* AXI GPIO register offsets. */
#define FH_AXI_GPIO_CH1_DATA         0x00000000U
#define FH_AXI_GPIO_CH1_TRI          0x00000004U
#define FH_AXI_GPIO_CH2_DATA         0x00000008U
#define FH_AXI_GPIO_CH2_TRI          0x0000000CU

/* axi_gpio_gmax_a_ctrl channel-1 bit assignment (must match Vivado wrapper). */
#define GMAX_CTRL_PWR_EN             (1U << 0)
#define GMAX_CTRL_CLK_EN             (1U << 1)
#define GMAX_CTRL_SYS_RST_N          (1U << 2)
#define GMAX_CTRL_CCI_EN             (1U << 3)
#define GMAX_CTRL_XCE_SLAMODE        (1U << 4)
#define GMAX_CTRL_TEXP1              (1U << 5)
#define GMAX_CTRL_TEXP2              (1U << 6)
#define GMAX_CTRL_SPI_SCK            (1U << 7)
#define GMAX_CTRL_SPI_SDI            (1U << 8)
#define GMAX_CTRL_RXDBG_INDEX_SHIFT  9U
#define GMAX_CTRL_RXDBG_INDEX_MASK   (0xFU << GMAX_CTRL_RXDBG_INDEX_SHIFT)
#define GMAX_CTRL_RXDBG_LANE         (1U << 13)
#define GMAX_CTRL_RXDBG_FREEZE       (1U << 14)
#define GMAX_CTRL_ALL_MASK           0x00007FFFU

/*
 * axi_gpio_gmax_a_ctrl channel-2 input mapping (v16 Vivado design):
 *   bit 0       : GMX_A_SDO_TDIG
 *   bits 16:1  : gmax_a_training_result[15:0]
 *   bit 17      : gmax_a_training_done
 *   bits 27:18 : selected D0/D1 captured candidate word[9:0]
 *   bit 28      : captured candidate valid
 *   bit 29      : CLK_OUT0 activity observed
 *   bit 30      : CLK_OUT1 activity observed
 *   bit 31      : selected lane raw ISERDESE3 activity observed
 */
#define GMAX_STATUS_SDO_TDIG             (1U << 0)
#define GMAX_STATUS_TRAINING_SHIFT       1U
#define GMAX_STATUS_TRAINING_RESULT_MASK 0x0001FFFEU
#define GMAX_STATUS_TRAINING_DONE_MASK   (1U << 17)
#define GMAX_STATUS_RXDBG_WORD_SHIFT     18U
#define GMAX_STATUS_RXDBG_WORD_MASK      (0x3FFU << GMAX_STATUS_RXDBG_WORD_SHIFT)
#define GMAX_STATUS_RXDBG_VALID_MASK     (1U << 28)
#define GMAX_STATUS_RXDBG_CLK0_MASK      (1U << 29)
#define GMAX_STATUS_RXDBG_CLK1_MASK      (1U << 30)
#define GMAX_STATUS_RXDBG_ACTIVITY_MASK  (1U << 31)
#define GMAX_STATUS_CH2_INPUT_MASK       0xFFFFFFFFU

/*
 * SAFE/OFF state used by firmware:
 *   PWR_EN=0, CLK_EN=0, SYS_RST_N=0, CCI_EN=1 (I2C), SLAMODE=0 (0x10),
 *   TEXP1/2=0, SCK=0, SDI=0.
 */
#define GMAX_CTRL_SAFE_I2C           GMAX_CTRL_CCI_EN

/* GMAX3412 serial-interface constants from datasheet V1.0. */
#define GMAX_I2C_ADDR_0              0x10U
#define GMAX_I2C_ADDR_1              0x1AU
#define GMAX_I2C_REG_CLK_STREAM      0x2E00U
#define GMAX_I2C_REG_REG_HOLD        0x2E01U
#define GMAX_I2C_REG_COLR_EN         0x2E02U
#define GMAX_I2C_REG_PGA_GAIN        0x2EAEU
#define GMAX_I2C_REG_SDO_TDIG_SEL    0x2EAFU
#define GMAX_I2C_REG_OUT_MODE_SEL    0x3000U
#define GMAX_I2C_REG_CH_CLK_EN       0x3005U
#define GMAX_I2C_REG_HLO_ORDER       0x3010U
#define GMAX_I2C_REG_TP_LOW          0x3014U
#define GMAX_I2C_REG_TP_HIGH         0x3015U
#define GMAX_I2C_REG_PHY_CTRL0       0x3023U
#define GMAX_I2C_REG_PHY_CTRL1       0x3024U
#define GMAX_I2C_REG_D_TEMP_L        0x3257U
#define GMAX_I2C_REG_D_TEMP_H        0x3258U
#define GMAX_I2C_REG_PWR_UP_EN       0x3301U
#define GMAX_I2C_REG_PWR_DOWN_EN     0x3302U
#define GMAX_I2C_REG_IMAGE_TEST      0x3500U

#define GMAX_SPI_REG_CLK_STREAM      0x0000U
#define GMAX_SPI_REG_SDO_TDIG_SEL    0x00AFU

#define GMAX_CLK_STABLE_EN_MASK      0x01U
#define GMAX_STREAM_EN_MASK          0x02U
#define GMAX_REG_HOLD_MASK           0x01U
#define GMAX_SDO_TDIG_SEL_MASK       0x02U
#define GMAX_CH_CLK_EN_MASK          0x01U
#define GMAX_PWR_UP_EN_MASK          0x01U
#define GMAX_PWR_DOWN_EN_MASK        0x01U
#define GMAX_PHY_CHN_EN_MASK         0xF0U
#define GMAX_PHY_CAL_BIT0_MASK       0x01U
#define GMAX_PHY_CAL_BITS21_MASK     0x06U
#define GMAX_PHY_CTRL1_BIT5_MASK     0x20U
#define GMAX_TRAINING_WORD_10B        0x0165U

/* Conservative bench delays; all meet/exceed the GMAX3412 minimums. */
#define GMAX_RAIL_SETTLE_US          100000U  /* local LM3880 rail sequence + margin */
#define GMAX_RESET_TO_CLK_US         10U      /* datasheet minimum is 2 us */
#define GMAX_CLK_SETTLE_US           5000U    /* external oscillator settling margin */
#define GMAX_INTERNAL_PLL_US         5000U    /* after CLK_STABLE_EN */
#define GMAX_INTERNAL_PWRUP_US       80000U   /* after PWR_UP_EN */
#define GMAX_CH_CLK_SETTLE_US        1000U
#define GMAX_PHY_STEP_US             1000U
#define GMAX_STREAM_SETTLE_US        1000U
#define GMAX_TRAINING_POLL_US        10U      /* v15: fast poll to catch retry-done interval */
#define GMAX_TRAINING_LOG_DEPTH      64U      /* completed attempts retained without UART in fast loop */
#define GMAX_TRAINING_TIMEOUT_US     2000000U /* allow automatic/retry training up to 2 s */
#define GMAX_FRAME_PULSE_US          100U
#define GMAX_POWER_DOWN_SETTLE_US    10000U
#define GMAX_SPI_HALF_PERIOD_US      2U       /* intentionally very slow for scope/debug */
#define GMAX_IIC_IDLE_TIMEOUT_US     100000U

typedef struct {
    u16 Address;
    u8 Value;
} GmaxReg8;

/*
 * Gpixel GMAX3412 Datasheet V1.0, Table 16:
 *   10-bit Sub-LVDS @ 1.20 Gb/s, x1 PGA gain.
 *
 * The datasheet table contains 532 address entries. 0x3257/0x3258 are
 * marked D_TEMP rather than configuration values; they are temperature
 * readout bytes and are deliberately omitted, leaving 530 configuration
 * writes below. Entries are sorted by I2C address for deterministic logging.
 */
static const GmaxReg8 Gmax10b1200Config[] = {
    {0x2E00U, 0x00U}, /* SPI 0x0000 */
    {0x2E01U, 0x00U}, /* SPI 0x0001 */
    {0x2E02U, 0x00U}, /* SPI 0x0002 */
    {0x2E03U, 0x02U}, /* SPI 0x0003 */
    {0x2E04U, 0x00U}, /* SPI 0x0004 */
    {0x2E05U, 0x08U}, /* SPI 0x0005 */
    {0x2E06U, 0x00U}, /* SPI 0x0006 */
    {0x2E07U, 0x01U}, /* SPI 0x0007 */
    {0x2E08U, 0x00U}, /* SPI 0x0008 */
    {0x2E09U, 0x00U}, /* SPI 0x0009 */
    {0x2E0AU, 0x00U}, /* SPI 0x000A */
    {0x2E0BU, 0x00U}, /* SPI 0x000B */
    {0x2E0CU, 0x00U}, /* SPI 0x000C */
    {0x2E0DU, 0x00U}, /* SPI 0x000D */
    {0x2E0EU, 0x00U}, /* SPI 0x000E */
    {0x2E0FU, 0x00U}, /* SPI 0x000F */
    {0x2E10U, 0x01U}, /* SPI 0x0010 */
    {0x2E11U, 0x00U}, /* SPI 0x0011 */
    {0x2E12U, 0x0CU}, /* SPI 0x0012 */
    {0x2E13U, 0x0CU}, /* SPI 0x0013 */
    {0x2E14U, 0x01U}, /* SPI 0x0014 */
    {0x2E15U, 0x00U}, /* SPI 0x0015 */
    {0x2E16U, 0x00U}, /* SPI 0x0016 */
    {0x2E17U, 0x00U}, /* SPI 0x0017 */
    {0x2E18U, 0x00U}, /* SPI 0x0018 */
    {0x2E19U, 0x0CU}, /* SPI 0x0019 */
    {0x2E1AU, 0x0CU}, /* SPI 0x001A */
    {0x2E1BU, 0x00U}, /* SPI 0x001B */
    {0x2E1CU, 0x00U}, /* SPI 0x001C */
    {0x2E1DU, 0x08U}, /* SPI 0x001D */
    {0x2E1EU, 0x00U}, /* SPI 0x001E */
    {0x2E1FU, 0x00U}, /* SPI 0x001F */
    {0x2E20U, 0x0CU}, /* SPI 0x0020 */
    {0x2E21U, 0x00U}, /* SPI 0x0021 */
    {0x2E22U, 0x00U}, /* SPI 0x0022 */
    {0x2E23U, 0x00U}, /* SPI 0x0023 */
    {0x2E24U, 0x00U}, /* SPI 0x0024 */
    {0x2E25U, 0x00U}, /* SPI 0x0025 */
    {0x2E26U, 0x00U}, /* SPI 0x0026 */
    {0x2E27U, 0x00U}, /* SPI 0x0027 */
    {0x2E28U, 0x00U}, /* SPI 0x0028 */
    {0x2E29U, 0x00U}, /* SPI 0x0029 */
    {0x2E2AU, 0x00U}, /* SPI 0x002A */
    {0x2E2BU, 0x00U}, /* SPI 0x002B */
    {0x2E2CU, 0x00U}, /* SPI 0x002C */
    {0x2E2DU, 0x00U}, /* SPI 0x002D */
    {0x2E2EU, 0x00U}, /* SPI 0x002E */
    {0x2E2FU, 0x00U}, /* SPI 0x002F */
    {0x2E30U, 0x00U}, /* SPI 0x0030 */
    {0x2E31U, 0x00U}, /* SPI 0x0031 */
    {0x2E32U, 0x00U}, /* SPI 0x0032 */
    {0x2E33U, 0x00U}, /* SPI 0x0033 */
    {0x2E34U, 0x00U}, /* SPI 0x0034 */
    {0x2E35U, 0x00U}, /* SPI 0x0035 */
    {0x2E36U, 0x00U}, /* SPI 0x0036 */
    {0x2E37U, 0x00U}, /* SPI 0x0037 */
    {0x2E38U, 0x00U}, /* SPI 0x0038 */
    {0x2E39U, 0x00U}, /* SPI 0x0039 */
    {0x2E3AU, 0x00U}, /* SPI 0x003A */
    {0x2E3BU, 0x00U}, /* SPI 0x003B */
    {0x2E3CU, 0x00U}, /* SPI 0x003C */
    {0x2E3DU, 0x0FU}, /* SPI 0x003D */
    {0x2E3EU, 0x06U}, /* SPI 0x003E */
    {0x2E3FU, 0x00U}, /* SPI 0x003F */
    {0x2E40U, 0x02U}, /* SPI 0x0040 */
    {0x2E41U, 0x03U}, /* SPI 0x0041 */
    {0x2E42U, 0x4EU}, /* SPI 0x0042 */
    {0x2E43U, 0x01U}, /* SPI 0x0043 */
    {0x2E44U, 0x02U}, /* SPI 0x0044 */
    {0x2E45U, 0x02U}, /* SPI 0x0045 */
    {0x2E46U, 0x02U}, /* SPI 0x0046 */
    {0x2E47U, 0x28U}, /* SPI 0x0047 */
    {0x2E48U, 0x04U}, /* SPI 0x0048 */
    {0x2E49U, 0x06U}, /* SPI 0x0049 */
    {0x2E4AU, 0x00U}, /* SPI 0x004A */
    {0x2E4BU, 0x07U}, /* SPI 0x004B */
    {0x2E4CU, 0x00U}, /* SPI 0x004C */
    {0x2E4DU, 0xA4U}, /* SPI 0x004D */
    {0x2E4EU, 0x84U}, /* SPI 0x004E */
    {0x2E4FU, 0x62U}, /* SPI 0x004F */
    {0x2E50U, 0x02U}, /* SPI 0x0050 */
    {0x2E51U, 0x46U}, /* SPI 0x0051 */
    {0x2E52U, 0x5DU}, /* SPI 0x0052 */
    {0x2E53U, 0x05U}, /* SPI 0x0053 */
    {0x2E54U, 0x41U}, /* SPI 0x0054 */
    {0x2E55U, 0xFFU}, /* SPI 0x0055 */
    {0x2E56U, 0xFFU}, /* SPI 0x0056 */
    {0x2E57U, 0xFFU}, /* SPI 0x0057 */
    {0x2E58U, 0xFFU}, /* SPI 0x0058 */
    {0x2E59U, 0x39U}, /* SPI 0x0059 */
    {0x2E5AU, 0x57U}, /* SPI 0x005A */
    {0x2E5BU, 0x12U}, /* SPI 0x005B */
    {0x2E5CU, 0xFFU}, /* SPI 0x005C */
    {0x2E5DU, 0xFFU}, /* SPI 0x005D */
    {0x2E5EU, 0xFFU}, /* SPI 0x005E */
    {0x2E5FU, 0x01U}, /* SPI 0x005F */
    {0x2E60U, 0x7CU}, /* SPI 0x0060 */
    {0x2E61U, 0x01U}, /* SPI 0x0061 */
    {0x2E62U, 0x7CU}, /* SPI 0x0062 */
    {0x2E63U, 0xFFU}, /* SPI 0x0063 */
    {0x2E64U, 0xFFU}, /* SPI 0x0064 */
    {0x2E65U, 0x01U}, /* SPI 0x0065 */
    {0x2E66U, 0x1EU}, /* SPI 0x0066 */
    {0x2E67U, 0x0AU}, /* SPI 0x0067 */
    {0x2E68U, 0x7CU}, /* SPI 0x0068 */
    {0x2E69U, 0x01U}, /* SPI 0x0069 */
    {0x2E6AU, 0x38U}, /* SPI 0x006A */
    {0x2E6BU, 0x3AU}, /* SPI 0x006B */
    {0x2E6CU, 0x7AU}, /* SPI 0x006C */
    {0x2E6DU, 0x03U}, /* SPI 0x006D */
    {0x2E6EU, 0x16U}, /* SPI 0x006E */
    {0x2E6FU, 0x23U}, /* SPI 0x006F */
    {0x2E70U, 0x5FU}, /* SPI 0x0070 */
    {0x2E71U, 0x01U}, /* SPI 0x0071 */
    {0x2E72U, 0x64U}, /* SPI 0x0072 */
    {0x2E73U, 0xFFU}, /* SPI 0x0073 */
    {0x2E74U, 0xFFU}, /* SPI 0x0074 */
    {0x2E75U, 0x02U}, /* SPI 0x0075 */
    {0x2E76U, 0x64U}, /* SPI 0x0076 */
    {0x2E77U, 0xFFU}, /* SPI 0x0077 */
    {0x2E78U, 0xFFU}, /* SPI 0x0078 */
    {0x2E79U, 0x04U}, /* SPI 0x0079 */
    {0x2E7AU, 0x15U}, /* SPI 0x007A */
    {0x2E7BU, 0x24U}, /* SPI 0x007B */
    {0x2E7CU, 0x5FU}, /* SPI 0x007C */
    {0x2E7DU, 0x01U}, /* SPI 0x007D */
    {0x2E7EU, 0x02U}, /* SPI 0x007E */
    {0x2E7FU, 0x21U}, /* SPI 0x007F */
    {0x2E80U, 0x22U}, /* SPI 0x0080 */
    {0x2E81U, 0x04U}, /* SPI 0x0081 */
    {0x2E82U, 0x15U}, /* SPI 0x0082 */
    {0x2E83U, 0x24U}, /* SPI 0x0083 */
    {0x2E84U, 0x5FU}, /* SPI 0x0084 */
    {0x2E85U, 0x14U}, /* SPI 0x0085 */
    {0x2E86U, 0x15U}, /* SPI 0x0086 */
    {0x2E87U, 0x5DU}, /* SPI 0x0087 */
    {0x2E88U, 0x5FU}, /* SPI 0x0088 */
    {0x2E89U, 0x16U}, /* SPI 0x0089 */
    {0x2E8AU, 0x1CU}, /* SPI 0x008A */
    {0x2E8BU, 0x19U}, /* SPI 0x008B */
    {0x2E8CU, 0xFFU}, /* SPI 0x008C */
    {0x2E8DU, 0xFFU}, /* SPI 0x008D */
    {0x2E8EU, 0xFFU}, /* SPI 0x008E */
    {0x2E8FU, 0xFFU}, /* SPI 0x008F */
    {0x2E90U, 0xFFU}, /* SPI 0x0090 */
    {0x2E91U, 0x01U}, /* SPI 0x0091 */
    {0x2E92U, 0x02U}, /* SPI 0x0092 */
    {0x2E93U, 0xFFU}, /* SPI 0x0093 */
    {0x2E94U, 0xFFU}, /* SPI 0x0094 */
    {0x2E95U, 0xFFU}, /* SPI 0x0095 */
    {0x2E96U, 0xFFU}, /* SPI 0x0096 */
    {0x2E97U, 0xFFU}, /* SPI 0x0097 */
    {0x2E98U, 0xFFU}, /* SPI 0x0098 */
    {0x2E99U, 0xFFU}, /* SPI 0x0099 */
    {0x2E9AU, 0xFFU}, /* SPI 0x009A */
    {0x2E9BU, 0x24U}, /* SPI 0x009B */
    {0x2E9CU, 0x1CU}, /* SPI 0x009C */
    {0x2E9DU, 0x1EU}, /* SPI 0x009D */
    {0x2E9EU, 0x0CU}, /* SPI 0x009E */
    {0x2E9FU, 0x03U}, /* SPI 0x009F */
    {0x2EA0U, 0x00U}, /* SPI 0x00A0 */
    {0x2EA1U, 0x01U}, /* SPI 0x00A1 */
    {0x2EA2U, 0x00U}, /* SPI 0x00A2 */
    {0x2EA3U, 0x01U}, /* SPI 0x00A3 */
    {0x2EA4U, 0x03U}, /* SPI 0x00A4 */
    {0x2EA5U, 0x01U}, /* SPI 0x00A5 */
    {0x2EA6U, 0x01U}, /* SPI 0x00A6 */
    {0x2EA7U, 0x00U}, /* SPI 0x00A7 */
    {0x2EA8U, 0x01U}, /* SPI 0x00A8 */
    {0x2EA9U, 0x1EU}, /* SPI 0x00A9 */
    {0x2EAAU, 0x0CU}, /* SPI 0x00AA */
    {0x2EABU, 0x00U}, /* SPI 0x00AB */
    {0x2EACU, 0x00U}, /* SPI 0x00AC */
    {0x2EADU, 0x01U}, /* SPI 0x00AD */
    {0x2EAEU, 0x12U}, /* SPI 0x00AE */
    {0x2EAFU, 0x01U}, /* SPI 0x00AF */
    {0x2EB0U, 0x01U}, /* SPI 0x00B0 */
    {0x2EB1U, 0x00U}, /* SPI 0x00B1 */
    {0x2EB2U, 0x00U}, /* SPI 0x00B2 */
    {0x2EB3U, 0x00U}, /* SPI 0x00B3 */
    {0x2EB4U, 0x00U}, /* SPI 0x00B4 */
    {0x2EB5U, 0x00U}, /* SPI 0x00B5 */
    {0x2EB6U, 0x00U}, /* SPI 0x00B6 */
    {0x2EB7U, 0x00U}, /* SPI 0x00B7 */
    {0x2EB8U, 0x00U}, /* SPI 0x00B8 */
    {0x2EB9U, 0x00U}, /* SPI 0x00B9 */
    {0x2EBAU, 0x00U}, /* SPI 0x00BA */
    {0x2EBBU, 0x00U}, /* SPI 0x00BB */
    {0x3000U, 0x00U}, /* SPI 0x0200 */
    {0x3001U, 0x02U}, /* SPI 0x0201 */
    {0x3002U, 0x02U}, /* SPI 0x0202 */
    {0x3003U, 0x00U}, /* SPI 0x0203 */
    {0x3004U, 0x03U}, /* SPI 0x0204 */
    {0x3005U, 0x00U}, /* SPI 0x0205 */
    {0x3006U, 0x00U}, /* SPI 0x0206 */
    {0x3007U, 0x00U}, /* SPI 0x0207 */
    {0x3008U, 0x00U}, /* SPI 0x0208 */
    {0x3009U, 0x06U}, /* SPI 0x0209 */
    {0x300AU, 0x00U}, /* SPI 0x020A */
    {0x300BU, 0x01U}, /* SPI 0x020B */
    {0x300CU, 0x01U}, /* SPI 0x020C */
    {0x300DU, 0x0FU}, /* SPI 0x020D */
    {0x300EU, 0x00U}, /* SPI 0x020E */
    {0x300FU, 0x11U}, /* SPI 0x020F */
    {0x3010U, 0x01U}, /* SPI 0x0210 */
    {0x3011U, 0x01U}, /* SPI 0x0211 */
    {0x3012U, 0x00U}, /* SPI 0x0212 */
    {0x3013U, 0x00U}, /* SPI 0x0213 */
    {0x3014U, 0x65U}, /* SPI 0x0214 */
    {0x3015U, 0x01U}, /* SPI 0x0215 */
    {0x3016U, 0x04U}, /* SPI 0x0216 */
    {0x3017U, 0x00U}, /* SPI 0x0217 */
    {0x3018U, 0x08U}, /* SPI 0x0218 */
    {0x3019U, 0x07U}, /* SPI 0x0219 */
    {0x301AU, 0x10U}, /* SPI 0x021A */
    {0x301BU, 0x07U}, /* SPI 0x021B */
    {0x301CU, 0x27U}, /* SPI 0x021C */
    {0x301DU, 0x00U}, /* SPI 0x021D */
    {0x301EU, 0x0BU}, /* SPI 0x021E */
    {0x301FU, 0x09U}, /* SPI 0x021F */
    {0x3020U, 0x05U}, /* SPI 0x0220 */
    {0x3021U, 0x06U}, /* SPI 0x0221 */
    {0x3022U, 0x01U}, /* SPI 0x0222 */
    {0x3023U, 0xF8U}, /* SPI 0x0223 */
    {0x3024U, 0x14U}, /* SPI 0x0224 */
    {0x3025U, 0x00U}, /* SPI 0x0225 */
    {0x3026U, 0x00U}, /* SPI 0x0226 */
    {0x3027U, 0x00U}, /* SPI 0x0227 */
    {0x3028U, 0x00U}, /* SPI 0x0228 */
    {0x3029U, 0x00U}, /* SPI 0x0229 */
    {0x302AU, 0x04U}, /* SPI 0x022A */
    {0x302BU, 0x04U}, /* SPI 0x022B */
    {0x302CU, 0x04U}, /* SPI 0x022C */
    {0x302DU, 0x04U}, /* SPI 0x022D */
    {0x302EU, 0x00U}, /* SPI 0x022E */
    {0x302FU, 0x00U}, /* SPI 0x022F */
    {0x3030U, 0x00U}, /* SPI 0x0230 */
    {0x3031U, 0x00U}, /* SPI 0x0231 */
    {0x3032U, 0x00U}, /* SPI 0x0232 */
    {0x3033U, 0x1FU}, /* SPI 0x0233 */
    {0x3034U, 0x1FU}, /* SPI 0x0234 */
    {0x3035U, 0x08U}, /* SPI 0x0235 */
    {0x3036U, 0x08U}, /* SPI 0x0236 */
    {0x3037U, 0x00U}, /* SPI 0x0237 */
    {0x3038U, 0x10U}, /* SPI 0x0238 */
    {0x3200U, 0x20U}, /* SPI 0x0400 */
    {0x3201U, 0x00U}, /* SPI 0x0401 */
    {0x3202U, 0x04U}, /* SPI 0x0402 */
    {0x3203U, 0x03U}, /* SPI 0x0403 */
    {0x3204U, 0x20U}, /* SPI 0x0404 */
    {0x3205U, 0x03U}, /* SPI 0x0405 */
    {0x3206U, 0x03U}, /* SPI 0x0406 */
    {0x3207U, 0x03U}, /* SPI 0x0407 */
    {0x3208U, 0x16U}, /* SPI 0x0408 */
    {0x3209U, 0x04U}, /* SPI 0x0409 */
    {0x320AU, 0x00U}, /* SPI 0x040A */
    {0x320BU, 0x16U}, /* SPI 0x040B */
    {0x320CU, 0x04U}, /* SPI 0x040C */
    {0x320DU, 0x16U}, /* SPI 0x040D */
    {0x320EU, 0x0FU}, /* SPI 0x040E */
    {0x320FU, 0x00U}, /* SPI 0x040F */
    {0x3210U, 0x11U}, /* SPI 0x0410 */
    {0x3211U, 0x07U}, /* SPI 0x0411 */
    {0x3212U, 0x00U}, /* SPI 0x0412 */
    {0x3213U, 0x0EU}, /* SPI 0x0413 */
    {0x3214U, 0x1BU}, /* SPI 0x0414 */
    {0x3215U, 0x03U}, /* SPI 0x0415 */
    {0x3216U, 0x21U}, /* SPI 0x0416 */
    {0x3217U, 0x04U}, /* SPI 0x0417 */
    {0x3218U, 0x07U}, /* SPI 0x0418 */
    {0x3219U, 0x00U}, /* SPI 0x0419 */
    {0x321AU, 0x29U}, /* SPI 0x041A */
    {0x321BU, 0x07U}, /* SPI 0x041B */
    {0x321CU, 0x00U}, /* SPI 0x041C */
    {0x321DU, 0x04U}, /* SPI 0x041D */
    {0x321EU, 0x29U}, /* SPI 0x041E */
    {0x321FU, 0x04U}, /* SPI 0x041F */
    {0x3220U, 0x07U}, /* SPI 0x0420 */
    {0x3221U, 0x00U}, /* SPI 0x0421 */
    {0x3222U, 0x0FU}, /* SPI 0x0422 */
    {0x3223U, 0x03U}, /* SPI 0x0423 */
    {0x3224U, 0x00U}, /* SPI 0x0424 */
    {0x3225U, 0x00U}, /* SPI 0x0425 */
    {0x3226U, 0x29U}, /* SPI 0x0426 */
    {0x3227U, 0x03U}, /* SPI 0x0427 */
    {0x3228U, 0x00U}, /* SPI 0x0428 */
    {0x3229U, 0x00U}, /* SPI 0x0429 */
    {0x322AU, 0x11U}, /* SPI 0x042A */
    {0x322BU, 0x03U}, /* SPI 0x042B */
    {0x322CU, 0x1BU}, /* SPI 0x042C */
    {0x322DU, 0x00U}, /* SPI 0x042D */
    {0x322EU, 0x07U}, /* SPI 0x042E */
    {0x322FU, 0x0FU}, /* SPI 0x042F */
    {0x3230U, 0x0EU}, /* SPI 0x0430 */
    {0x3231U, 0x6EU}, /* SPI 0x0431 */
    {0x3232U, 0x53U}, /* SPI 0x0432 */
    {0x3233U, 0x5BU}, /* SPI 0x0433 */
    {0x3234U, 0x4FU}, /* SPI 0x0434 */
    {0x3235U, 0x49U}, /* SPI 0x0435 */
    {0x3236U, 0x49U}, /* SPI 0x0436 */
    {0x3237U, 0x47U}, /* SPI 0x0437 */
    {0x3238U, 0x5EU}, /* SPI 0x0438 */
    {0x3239U, 0x47U}, /* SPI 0x0439 */
    {0x323AU, 0x53U}, /* SPI 0x043A */
    {0x323BU, 0x53U}, /* SPI 0x043B */
    {0x323CU, 0x49U}, /* SPI 0x043C */
    {0x323DU, 0x49U}, /* SPI 0x043D */
    {0x323EU, 0x68U}, /* SPI 0x043E */
    {0x323FU, 0x64U}, /* SPI 0x043F */
    {0x3240U, 0x00U}, /* SPI 0x0440 */
    {0x3241U, 0x1AU}, /* SPI 0x0441 */
    {0x3242U, 0x24U}, /* SPI 0x0442 */
    {0x3243U, 0x04U}, /* SPI 0x0443 */
    {0x3244U, 0x13U}, /* SPI 0x0444 */
    {0x3245U, 0x13U}, /* SPI 0x0445 */
    {0x3246U, 0x32U}, /* SPI 0x0446 */
    {0x3247U, 0x0AU}, /* SPI 0x0447 */
    {0x3248U, 0x7DU}, /* SPI 0x0448 */
    {0x3249U, 0x21U}, /* SPI 0x0449 */
    {0x324AU, 0x0EU}, /* SPI 0x044A */
    {0x324BU, 0x53U}, /* SPI 0x044B */
    {0x324CU, 0x84U}, /* SPI 0x044C */
    {0x324DU, 0x1CU}, /* SPI 0x044D */
    {0x324EU, 0x28U}, /* SPI 0x044E */
    {0x324FU, 0x07U}, /* SPI 0x044F */
    {0x3250U, 0x04U}, /* SPI 0x0450 */
    {0x3251U, 0x00U}, /* SPI 0x0451 */
    {0x3252U, 0x0FU}, /* SPI 0x0452 */
    {0x3253U, 0x00U}, /* SPI 0x0453 */
    {0x3254U, 0x00U}, /* SPI 0x0454 */
    {0x3255U, 0x00U}, /* SPI 0x0455 */
    {0x3256U, 0x00U}, /* SPI 0x0456 */
    {0x3300U, 0x00U}, /* SPI 0x0500 */
    {0x3301U, 0x00U}, /* SPI 0x0501 */
    {0x3302U, 0x00U}, /* SPI 0x0502 */
    {0x3303U, 0x00U}, /* SPI 0x0503 */
    {0x3304U, 0x00U}, /* SPI 0x0504 */
    {0x3305U, 0x00U}, /* SPI 0x0505 */
    {0x3306U, 0x00U}, /* SPI 0x0506 */
    {0x3307U, 0x01U}, /* SPI 0x0507 */
    {0x3308U, 0x00U}, /* SPI 0x0508 */
    {0x3309U, 0x01U}, /* SPI 0x0509 */
    {0x330AU, 0x00U}, /* SPI 0x050A */
    {0x330BU, 0x01U}, /* SPI 0x050B */
    {0x330CU, 0x00U}, /* SPI 0x050C */
    {0x330DU, 0x01U}, /* SPI 0x050D */
    {0x330EU, 0x00U}, /* SPI 0x050E */
    {0x330FU, 0x01U}, /* SPI 0x050F */
    {0x3310U, 0x00U}, /* SPI 0x0510 */
    {0x3311U, 0x01U}, /* SPI 0x0511 */
    {0x3312U, 0x00U}, /* SPI 0x0512 */
    {0x3313U, 0x2CU}, /* SPI 0x0513 */
    {0x3314U, 0x01U}, /* SPI 0x0514 */
    {0x3315U, 0x01U}, /* SPI 0x0515 */
    {0x3316U, 0x00U}, /* SPI 0x0516 */
    {0x3317U, 0xE2U}, /* SPI 0x0517 */
    {0x3318U, 0x04U}, /* SPI 0x0518 */
    {0x3319U, 0xE2U}, /* SPI 0x0519 */
    {0x331AU, 0x04U}, /* SPI 0x051A */
    {0x331BU, 0xE2U}, /* SPI 0x051B */
    {0x331CU, 0x04U}, /* SPI 0x051C */
    {0x331DU, 0xE2U}, /* SPI 0x051D */
    {0x331EU, 0x04U}, /* SPI 0x051E */
    {0x331FU, 0xE2U}, /* SPI 0x051F */
    {0x3320U, 0x04U}, /* SPI 0x0520 */
    {0x3321U, 0xE2U}, /* SPI 0x0521 */
    {0x3322U, 0x04U}, /* SPI 0x0522 */
    {0x3323U, 0xEEU}, /* SPI 0x0523 */
    {0x3324U, 0x02U}, /* SPI 0x0524 */
    {0x3325U, 0xEEU}, /* SPI 0x0525 */
    {0x3326U, 0x02U}, /* SPI 0x0526 */
    {0x3327U, 0x01U}, /* SPI 0x0527 */
    {0x3328U, 0x00U}, /* SPI 0x0528 */
    {0x3329U, 0x01U}, /* SPI 0x0529 */
    {0x332AU, 0x00U}, /* SPI 0x052A */
    {0x332BU, 0x01U}, /* SPI 0x052B */
    {0x332CU, 0x00U}, /* SPI 0x052C */
    {0x332DU, 0x01U}, /* SPI 0x052D */
    {0x332EU, 0x00U}, /* SPI 0x052E */
    {0x332FU, 0x77U}, /* SPI 0x052F */
    {0x3330U, 0x01U}, /* SPI 0x0530 */
    {0x3331U, 0x01U}, /* SPI 0x0531 */
    {0x3332U, 0x00U}, /* SPI 0x0532 */
    {0x3333U, 0xE2U}, /* SPI 0x0533 */
    {0x3334U, 0x04U}, /* SPI 0x0534 */
    {0x3335U, 0xE2U}, /* SPI 0x0535 */
    {0x3336U, 0x04U}, /* SPI 0x0536 */
    {0x3337U, 0xE2U}, /* SPI 0x0537 */
    {0x3338U, 0x04U}, /* SPI 0x0538 */
    {0x3339U, 0xE2U}, /* SPI 0x0539 */
    {0x333AU, 0x04U}, /* SPI 0x053A */
    {0x333BU, 0xE2U}, /* SPI 0x053B */
    {0x333CU, 0x04U}, /* SPI 0x053C */
    {0x333DU, 0xE2U}, /* SPI 0x053D */
    {0x333EU, 0x04U}, /* SPI 0x053E */
    {0x333FU, 0x01U}, /* SPI 0x053F */
    {0x3340U, 0x00U}, /* SPI 0x0540 */
    {0x3341U, 0x01U}, /* SPI 0x0541 */
    {0x3342U, 0x00U}, /* SPI 0x0542 */
    {0x3343U, 0x01U}, /* SPI 0x0543 */
    {0x3344U, 0x00U}, /* SPI 0x0544 */
    {0x3345U, 0x00U}, /* SPI 0x0545 */
    {0x3346U, 0x00U}, /* SPI 0x0546 */
    {0x3347U, 0x00U}, /* SPI 0x0547 */
    {0x3348U, 0x00U}, /* SPI 0x0548 */
    {0x3349U, 0x00U}, /* SPI 0x0549 */
    {0x334AU, 0x00U}, /* SPI 0x054A */
    {0x334BU, 0x00U}, /* SPI 0x054B */
    {0x334CU, 0x00U}, /* SPI 0x054C */
    {0x334DU, 0x10U}, /* SPI 0x054D */
    {0x334EU, 0x32U}, /* SPI 0x054E */
    {0x334FU, 0x54U}, /* SPI 0x054F */
    {0x3350U, 0x86U}, /* SPI 0x0550 */
    {0x3351U, 0xA9U}, /* SPI 0x0551 */
    {0x3352U, 0xCBU}, /* SPI 0x0552 */
    {0x3353U, 0xEDU}, /* SPI 0x0553 */
    {0x3354U, 0x7FU}, /* SPI 0x0554 */
    {0x3355U, 0x10U}, /* SPI 0x0555 */
    {0x3356U, 0x32U}, /* SPI 0x0556 */
    {0x3357U, 0x54U}, /* SPI 0x0557 */
    {0x3358U, 0x87U}, /* SPI 0x0558 */
    {0x3359U, 0xA9U}, /* SPI 0x0559 */
    {0x335AU, 0xCBU}, /* SPI 0x055A */
    {0x335BU, 0xEDU}, /* SPI 0x055B */
    {0x335CU, 0x5FU}, /* SPI 0x055C */
    {0x335DU, 0x00U}, /* SPI 0x055D */
    {0x335EU, 0x00U}, /* SPI 0x055E */
    {0x335FU, 0x00U}, /* SPI 0x055F */
    {0x3360U, 0x00U}, /* SPI 0x0560 */
    {0x3361U, 0x01U}, /* SPI 0x0561 */
    {0x3362U, 0x00U}, /* SPI 0x0562 */
    {0x3363U, 0x76U}, /* SPI 0x0563 */
    {0x3364U, 0xE8U}, /* SPI 0x0564 */
    {0x3365U, 0x03U}, /* SPI 0x0565 */
    {0x3366U, 0xE8U}, /* SPI 0x0566 */
    {0x3367U, 0x03U}, /* SPI 0x0567 */
    {0x3368U, 0x88U}, /* SPI 0x0568 */
    {0x3369U, 0x13U}, /* SPI 0x0569 */
    {0x336AU, 0x88U}, /* SPI 0x056A */
    {0x336BU, 0x13U}, /* SPI 0x056B */
    {0x336CU, 0x00U}, /* SPI 0x056C */
    {0x3400U, 0x00U}, /* SPI 0x0600 */
    {0x3401U, 0x12U}, /* SPI 0x0601 */
    {0x3402U, 0x00U}, /* SPI 0x0602 */
    {0x3403U, 0x01U}, /* SPI 0x0603 */
    {0x3404U, 0x64U}, /* SPI 0x0604 */
    {0x3405U, 0x02U}, /* SPI 0x0605 */
    {0x3500U, 0x10U}, /* SPI 0x0700 */
    {0x3501U, 0x86U}, /* SPI 0x0701 */
    {0x3502U, 0x00U}, /* SPI 0x0702 */
    {0x3503U, 0x00U}, /* SPI 0x0703 */
    {0x3504U, 0x00U}, /* SPI 0x0704 */
    {0x3505U, 0x00U}, /* SPI 0x0705 */
    {0x3506U, 0x00U}, /* SPI 0x0706 */
    {0x3507U, 0x00U}, /* SPI 0x0707 */
    {0x3508U, 0x00U}, /* SPI 0x0708 */
    {0x3509U, 0x00U}, /* SPI 0x0709 */
    {0x350AU, 0x00U}, /* SPI 0x070A */
    {0x350BU, 0x00U}, /* SPI 0x070B */
    {0x350CU, 0x00U}, /* SPI 0x070C */
    {0x350DU, 0x00U}, /* SPI 0x070D */
    {0x350EU, 0x00U}, /* SPI 0x070E */
    {0x350FU, 0x00U}, /* SPI 0x070F */
    {0x3510U, 0x00U}, /* SPI 0x0710 */
    {0x3511U, 0x00U}, /* SPI 0x0711 */
    {0x3512U, 0x10U}, /* SPI 0x0712 */
    {0x3513U, 0x00U}, /* SPI 0x0713 */
    {0x3514U, 0x00U}, /* SPI 0x0714 */
    {0x3515U, 0x00U}, /* SPI 0x0715 */
    {0x3516U, 0x00U}, /* SPI 0x0716 */
    {0x3517U, 0x00U}, /* SPI 0x0717 */
    {0x3518U, 0x00U}, /* SPI 0x0718 */
    {0x3519U, 0x00U}, /* SPI 0x0719 */
    {0x351AU, 0x00U}, /* SPI 0x071A */
    {0x351BU, 0x00U}, /* SPI 0x071B */
    {0x351CU, 0x00U}, /* SPI 0x071C */
    {0x351DU, 0x00U}, /* SPI 0x071D */
    {0x351EU, 0x00U}, /* SPI 0x071E */
    {0x351FU, 0x00U}, /* SPI 0x071F */
    {0x3520U, 0x00U}, /* SPI 0x0720 */
    {0x3521U, 0x00U}, /* SPI 0x0721 */
    {0x3522U, 0x10U}, /* SPI 0x0722 */
    {0x3523U, 0x52U}, /* SPI 0x0723 */
    {0x3524U, 0x04U}, /* SPI 0x0724 */
    {0x3525U, 0x00U}, /* SPI 0x0725 */
    {0x3526U, 0x00U}, /* SPI 0x0726 */
    {0x3527U, 0x00U}, /* SPI 0x0727 */
    {0x3528U, 0x00U}, /* SPI 0x0728 */
    {0x3529U, 0x00U}, /* SPI 0x0729 */
    {0x352AU, 0x00U}, /* SPI 0x072A */
    {0x3700U, 0xF0U}, /* SPI 0x0900 */
    {0x3701U, 0x08U}, /* SPI 0x0901 */
    {0x3702U, 0x6EU}, /* SPI 0x0902 */
    {0x3703U, 0x10U}, /* SPI 0x0903 */
    {0x3704U, 0x00U}, /* SPI 0x0904 */
    {0x3705U, 0x80U}, /* SPI 0x0905 */
    {0x3706U, 0x00U}, /* SPI 0x0906 */
    {0x3707U, 0x20U}, /* SPI 0x0907 */
    {0x3708U, 0x00U}, /* SPI 0x0908 */
    {0x3709U, 0x20U}, /* SPI 0x0909 */
    {0x370AU, 0x32U}, /* SPI 0x090A */
    {0x370BU, 0x00U}, /* SPI 0x090B */
    {0x370CU, 0x02U}, /* SPI 0x090C */
    {0x370DU, 0x24U}, /* SPI 0x090D */
    {0x370EU, 0x3FU}, /* SPI 0x090E */
    {0x370FU, 0x08U}, /* SPI 0x090F */
    {0x3710U, 0x37U}, /* SPI 0x0910 */
    {0x3711U, 0x00U}, /* SPI 0x0911 */
    {0x3712U, 0x00U}, /* SPI 0x0912 */
    {0x3713U, 0x3AU}, /* SPI 0x0913 */
    {0x3800U, 0xF0U}, /* SPI 0x0A00 */
    {0x3801U, 0x08U}, /* SPI 0x0A01 */
    {0x3802U, 0x6EU}, /* SPI 0x0A02 */
    {0x3803U, 0x10U}, /* SPI 0x0A03 */
    {0x3804U, 0x00U}, /* SPI 0x0A04 */
    {0x3805U, 0x80U}, /* SPI 0x0A05 */
    {0x3806U, 0x00U}, /* SPI 0x0A06 */
    {0x3807U, 0x20U}, /* SPI 0x0A07 */
    {0x3808U, 0x00U}, /* SPI 0x0A08 */
    {0x3809U, 0x20U}, /* SPI 0x0A09 */
    {0x380AU, 0x32U}, /* SPI 0x0A0A */
    {0x380BU, 0x00U}, /* SPI 0x0A0B */
    {0x380CU, 0x02U}, /* SPI 0x0A0C */
    {0x380DU, 0x24U}, /* SPI 0x0A0D */
    {0x380EU, 0x3FU}, /* SPI 0x0A0E */
    {0x380FU, 0x08U}, /* SPI 0x0A0F */
    {0x3810U, 0x37U}, /* SPI 0x0A10 */
    {0x3811U, 0x00U}, /* SPI 0x0A11 */
    {0x3812U, 0x00U}, /* SPI 0x0A12 */
    {0x3813U, 0x3AU}, /* SPI 0x0A13 */
};
#define GMAX_10B1200_CONFIG_COUNT ((u32)(sizeof(Gmax10b1200Config) / sizeof(Gmax10b1200Config[0])))


/*
 * PS-GTR SERDES PLL-status registers (UG1087).
 *
 * Lane 0 is FH_Carrier SATA:
 *   M2_SATA_REFCLK_150M -> MGT_505_CLK_P0/N0
 *
 * Lane 1 is FH_Carrier USB3:
 *   USB3_CLK100 -> MGT_505_CLK_P1/N1
 */
#define FH_GTR_L0_PLL_STATUS_READ_1  ((UINTPTR)0xFD4023E4U)
#define FH_GTR_L1_PLL_STATUS_READ_1  ((UINTPTR)0xFD4063E4U)

/*
 * PS-GTR reference-clock configuration registers.
 *
 * PLL_REF_SELx[4:0] is the nominal input-frequency code generated by
 * the Vivado PS Configuration Wizard:
 *   0x08 = 26 MHz
 *   0x0D = 100 MHz
 *   0x11 = 150 MHz
 *
 * FH_Carrier requires:
 *   PLL0 / SATA = 150 MHz -> 0x11
 *   PLL1 / USB3 = 100 MHz -> 0x0D
 */
#define FH_GTR_PLL_REF_SEL0           ((UINTPTR)0xFD410000U)
#define FH_GTR_PLL_REF_SEL1           ((UINTPTR)0xFD410004U)
#define FH_GTR_PLL_REF_SEL_MASK       0x0000001FU

/*
 * Reference-clock mux routing generated for the FH_Carrier PS-GTR mapping:
 *   lane 0 / SATA -> REFCLK0 path : masked value 0x02
 *   lane 1 / USB3 -> REFCLK1 path : masked value 0x08
 */
#define FH_GTR_L0_REF_CLK_SEL         ((UINTPTR)0xFD402860U)
#define FH_GTR_L1_REF_CLK_SEL         ((UINTPTR)0xFD402864U)
#define FH_GTR_L0_REF_CLK_SEL_MASK    0x00000082U
#define FH_GTR_L1_REF_CLK_SEL_MASK    0x00000088U
#define FH_GTR_L0_REF_CLK_SEL_EXPECT  0x00000002U
#define FH_GTR_L1_REF_CLK_SEL_EXPECT  0x00000008U

#define FH_GTR_SATA_REF_FREQ_CODE     0x11U
#define FH_GTR_USB3_REF_FREQ_CODE     0x0DU

/*
 * PS-GTR reset defaults observed/documented for this Zynq UltraScale+ block.
 * These are used only to distinguish "not initialized yet" from a genuine
 * Vivado PCW/XSA configuration mismatch.
 *
 * Lane 0 reset:
 *   PLL_REF_SEL0   = 0x0D (100 MHz reset code)
 *   L0_REF_CLK_SEL = 0x80
 *   PLL_STATUS     = 0x01
 *
 * Lane 1 reset:
 *   PLL_REF_SEL1   = 0x08 (26 MHz reset code)
 *   L1_REF_CLK_SEL = 0x80
 *   PLL_STATUS     = 0x01
 */
#define FH_GTR_L0_RESET_REF_FREQ_CODE 0x0DU
#define FH_GTR_L1_RESET_REF_FREQ_CODE 0x08U
#define FH_GTR_REF_CLK_SEL_RESET      0x00000080U
#define FH_GTR_PLL_STATUS_RESET       0x00000001U

#define FH_GTR_PLL_START_MASK         0x00000020U
#define FH_GTR_PLL_LOCK_MASK          0x00000010U
#define FH_GTR_PLL_COARSE_DONE_MASK   0x00000008U

/*
 * PS-GTR protocol assignment.
 *
 * ICM_CFG0:
 *   lane 0 protocol = bits [2:0]
 *   lane 1 protocol = bits [6:4]
 *
 * FH_Carrier:
 *   lane 0 = SATA0 -> code 2
 *   lane 1 = USB0  -> code 3
 */
#define FH_GTR_ICM_CFG0               ((UINTPTR)0xFD410010U)
#define FH_GTR_L0_PROTOCOL_MASK       0x00000007U
#define FH_GTR_L1_PROTOCOL_MASK       0x00000070U
#define FH_GTR_L0_PROTOCOL_SHIFT      0U
#define FH_GTR_L1_PROTOCOL_SHIFT      4U
#define FH_GTR_L0_PROTOCOL_EXPECT     2U
#define FH_GTR_L1_PROTOCOL_EXPECT     3U

/*
 * SATA AHCI port 0 status. PxSSTS is read-only and continuously updated.
 * DET = bits [3:0], SPD = bits [7:4], IPM = bits [11:8].
 */
#define FH_SATA_P0_SSTS               ((UINTPTR)0xFD0C0128U)
#define FH_SATA_SSTS_DET_MASK         0x0000000FU
#define FH_SATA_SSTS_SPD_MASK         0x000000F0U
#define FH_SATA_SSTS_IPM_MASK         0x00000F00U
#define FH_SATA_SSTS_SPD_SHIFT        4U
#define FH_SATA_SSTS_IPM_SHIFT        8U

/*
 * USB3_0 DWC3 global debug LTSSM register.
 *
 * This register is read-only and is preferred over PORTSC for bring-up
 * diagnostics because PORTSC access can itself time out when USB clocks or
 * resets are not valid.
 *
 * Fields used here:
 *   RxElecIdle     bit 30
 *   LTDBLinkState  bits [25:22]
 *   POWERDOWN      bits [10:9]
 *   LTDBClkState   bits [5:3]
 *   RxTermination  bit 1
 */
#define FH_USB3_GCTL                   ((UINTPTR)0xFE20C110U)
/* Exact mask used by AMD UG936/xsct_create_fsbl.tcl for USB IBERT bring-up. */
#define FH_USB3_GCTL_U0_LTSSM_MASK     0xFFFFDFFFU
#define FH_USB3_GCTL_LTSSM_FIELD_MASK  0x00003000U
#define FH_USB3_GCTL_LTSSM_EXPECT      0x00001000U

#define FH_USB3_GDBGLTSSM             ((UINTPTR)0xFE20C164U)
#define FH_USB3_RXELECIDLE_MASK        0x40000000U
#define FH_USB3_LINK_STATE_MASK        0x03C00000U
#define FH_USB3_LINK_STATE_SHIFT       22U
#define FH_USB3_POWERDOWN_MASK         0x00000600U
#define FH_USB3_POWERDOWN_SHIFT        9U
#define FH_USB3_CLK_STATE_MASK         0x00000038U
#define FH_USB3_CLK_STATE_SHIFT        3U
#define FH_USB3_RXTERM_MASK            0x00000002U
#define FH_USB3_LINK_POLL_INTERVAL_US  1000U
#define FH_USB3_LINK_POLL_TIMEOUT_US   2000000U

/*
 * AXI GPIO used by the PCIe reference-clock monitor.
 *
 * Current Vitis 2025.2 BSP canonical naming observed in xparameters.h:
 *
 *   XPAR_XGPIO_0_BASEADDR = 0xA0000000
 *   XPAR_XGPIO_0_HIGHADDR = 0xA000FFFF
 *   XPAR_XGPIO_0_GPIO_WIDTH = 32
 *   XPAR_XGPIO_0_IS_DUAL = 1
 *
 * Channel 1 (offset 0x00):
 *   clkmon_count_10ms
 *
 * Channel 2 (offset 0x08):
 *   clkmon_status
 *
 * Prefer the canonical XGPIO macro generated by the BSP.  The alternate
 * aliases are kept as fallbacks so the source survives small naming changes
 * if the Vivado Block Design instance is later renamed.
 */
#ifdef XPAR_XGPIO_0_BASEADDR

#define FH_CLKMON_AVAILABLE          1U
#define FH_CLKMON_BASEADDR           ((UINTPTR)XPAR_XGPIO_0_BASEADDR)

#elif defined(XPAR_AXI_GPIO_CLKMON_BASEADDR)

#define FH_CLKMON_AVAILABLE          1U
#define FH_CLKMON_BASEADDR           ((UINTPTR)XPAR_AXI_GPIO_CLKMON_BASEADDR)

#elif defined(XPAR_AXI_GPIO_CLKMON_0_BASEADDR)

#define FH_CLKMON_AVAILABLE          1U
#define FH_CLKMON_BASEADDR           ((UINTPTR)XPAR_AXI_GPIO_CLKMON_0_BASEADDR)

#elif defined(XPAR_AXI_GPIO_0_BASEADDR)

#define FH_CLKMON_AVAILABLE          1U
#define FH_CLKMON_BASEADDR           ((UINTPTR)XPAR_AXI_GPIO_0_BASEADDR)

#else

#define FH_CLKMON_AVAILABLE          0U
#define FH_CLKMON_BASEADDR           ((UINTPTR)0U)

#endif

#define FH_CLKMON_GPIO_CH1_DATA      0x00000000U
#define FH_CLKMON_GPIO_CH2_DATA      0x00000008U

#define FH_CLKMON_STATUS_VALID       0x00000001U
#define FH_CLKMON_STATUS_PRESENT     0x00000002U
#define FH_CLKMON_STATUS_IN_RANGE    0x00000004U

#define FH_PCIE_EXPECTED_KHZ         100000U
#define FH_PCIE_MIN_KHZ               99000U
#define FH_PCIE_MAX_KHZ              101000U

/*
 * CSU PCAP status: safe PS-side register used to verify that PL
 * configuration has completed before touching any PL AXI slave.
 *
 * pcap_status @ 0xFFCA3010
 *   bit 2 : PL_INIT
 *   bit 3 : PL_DONE
 *   bit 4 : PL_EOS
 *   bit 6 : PL_CFG_RESET_B
 */
#define FH_CSU_PCAP_STATUS            ((UINTPTR)0xFFCA3010U)
#define FH_PCAP_PL_INIT_MASK          0x00000004U
#define FH_PCAP_PL_DONE_MASK          0x00000008U
#define FH_PCAP_PL_EOS_MASK           0x00000010U
#define FH_PCAP_PL_CFG_RESET_B_MASK   0x00000040U
#define FH_PCAP_PL_READY_MASK         (FH_PCAP_PL_DONE_MASK | FH_PCAP_PL_EOS_MASK)

typedef enum {
    FH_CLOCK_PASS = 0,
    FH_CLOCK_FAIL,
    FH_CLOCK_CONFIG_ERROR,
    FH_CLOCK_NOT_INITIALIZED,
    FH_CLOCK_UNAVAILABLE
} FhClockResult;

static XGpioPs Gpio;
static XIicPs Iic0;
static XIicPs Iic1;

static int GpioReady = 0;
static int IicReady  = 0;
static int PacReady  = 0;
static int PacResponding = 0;
static int I2c1ResetWasAsserted = 0;
static int I2c1ResetReleasedByDiagnostic = 0;

/* FH_Sen4K / GMAX3412-A commanded state (not a substitute for DMM/scope). */
static XIic GmaxIic;
static int GmaxIicReady = 0;

static int GmaxControlReady = 0;
static int GmaxPowered = 0;
static int GmaxResetReleased = 0;
static int GmaxClockEnabled = 0;
static int GmaxConfigLoaded = 0;
static int GmaxInternalPowered = 0;
static int GmaxPhyCalibrated = 0;
static int GmaxStreamEnabled = 0;
static int GmaxPatternRecoveryRequired = 0;
static u32 GmaxCtrlShadow = GMAX_CTRL_SAFE_I2C;

/* Last complete reference-clock diagnostic results.
 * These are updated by test_differential_clocks() so the start-up summary
 * can include the same validated clock/link status shown by option 7.
 */
static FhClockResult LastSataClockResult = FH_CLOCK_UNAVAILABLE;
static FhClockResult LastUsbClockResult  = FH_CLOCK_UNAVAILABLE;
static FhClockResult LastPcieClockResult = FH_CLOCK_UNAVAILABLE;
static int LastUsbFunctional = 0;

static void show_menu(void)
{
    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf(" FH_Carrier Bring-Up Test\r\n");
    xil_printf("========================================\r\n");
    xil_printf(" 1   - Read Power-Good signals\r\n");
    xil_printf(" 2   - EEPROM full dump\r\n");
    xil_printf(" 3   - Show board EUI-48\r\n");
    xil_printf(" 4   - PAC1944 identification (PS I2C1/EMIO)\r\n");
    xil_printf(" 5   - PAC1944 rail measurements\r\n");
    xil_printf(" 6   - Re-run complete start-up diagnostics (incl. clocks)\r\n");
    xil_printf(" 7   - Complete reference clock diagnostics\r\n");
    xil_printf(" 8   - FH_Sen4K / GMAX3412-A diagnostics\r\n");
    xil_printf(" 9   - GMAX3412 emulator smoke test (on-chip checker)\r\n");
    xil_printf(" Q   - GMAX3412 repeated-capture qualification / hardware timing\r\n");
    xil_printf(" T   - GMAX3412 timing, stress and recovery regression\r\n");
    xil_printf(" D   - GMAX3412 emulator DDR capture / verify 3 frames\r\n");
    xil_printf(" R   - External reset test\r\n");
    xil_printf(" H   - Show menu\r\n");
    xil_printf(" ESC - Exit\r\n");
    xil_printf("----------------------------------------\r\n");
}

static int init_gpio(void)
{
    XGpioPs_Config *Cfg;

#ifdef SDT
    Cfg = XGpioPs_LookupConfig(XPAR_XGPIOPS_0_BASEADDR);
#else
    Cfg = XGpioPs_LookupConfig(XPAR_XGPIOPS_0_DEVICE_ID);
#endif

    if (Cfg == NULL)
        return XST_FAILURE;

    if (XGpioPs_CfgInitialize(&Gpio, Cfg, Cfg->BaseAddr) != XST_SUCCESS)
        return XST_FAILURE;

    XGpioPs_SetDirectionPin(&Gpio, PG_3V3_PIN, 0);
    XGpioPs_SetDirectionPin(&Gpio, PG_5V_PIN,  0);
    XGpioPs_SetDirectionPin(&Gpio, PG_1V8_PIN, 0);

    XGpioPs_SetOutputEnablePin(&Gpio, PG_3V3_PIN, 0);
    XGpioPs_SetOutputEnablePin(&Gpio, PG_5V_PIN,  0);
    XGpioPs_SetOutputEnablePin(&Gpio, PG_1V8_PIN, 0);

    return XST_SUCCESS;
}

static void test_power_good(void)
{
    u32 Pg33;
    u32 Pg5;
    u32 Pg18;

    xil_printf("\r\nPOWER-GOOD STATUS\r\n");
    xil_printf("-----------------\r\n");

    if (!GpioReady) {
        xil_printf("ERROR: GPIO not initialized.\r\n");
        return;
    }

    Pg33 = XGpioPs_ReadPin(&Gpio, PG_3V3_PIN);
    Pg5  = XGpioPs_ReadPin(&Gpio, PG_5V_PIN);
    Pg18 = XGpioPs_ReadPin(&Gpio, PG_1V8_PIN);

    xil_printf("PG_3V3 MIO39 : %d  %s\r\n", Pg33, Pg33 ? "OK" : "FAIL");
    xil_printf("PG_5V  MIO40 : %d  %s\r\n", Pg5,  Pg5  ? "OK" : "FAIL");
    xil_printf("PG_1V8 MIO41 : %d  %s\r\n", Pg18, Pg18 ? "OK" : "FAIL");

    if (Pg33 && Pg5 && Pg18)
        xil_printf("\r\nRESULT: ALL POWER-GOOD SIGNALS HIGH\r\n");
    else
        xil_printf("\r\nRESULT: POWER-GOOD FAILURE\r\n");
}

static int i2c_wait_idle(XIicPs *Instance, u32 TimeoutUs)
{
    const u32 PollUs = 10U;

    while (XIicPs_BusIsBusy(Instance)) {
        if (TimeoutUs <= PollUs)
            return XST_FAILURE;

        usleep(PollUs);
        TimeoutUs -= PollUs;
    }

    return XST_SUCCESS;
}

static void diag_step(unsigned int Step, const char *Text)
{
    xil_printf("\r\n[D%02u] %s\r\n", Step, Text);
}

static u32 diag_read32(const char *Name, UINTPTR Address)
{
    u32 Value;

    xil_printf("      MMIO READ  %s @ 0x%08lX ...\r\n",
               Name, (unsigned long)Address);
    Value = Xil_In32(Address);
    xil_printf("      MMIO READ  %s = 0x%08lX\r\n",
               Name, (unsigned long)Value);

    return Value;
}

static void print_i2c_status_bits(u32 Sr)
{
    xil_printf("      SR decode: BA=%u RXOVF=%u TXDV=%u RXDV=%u RXRW=%u\r\n",
               (unsigned int)((Sr & XIICPS_SR_BA_MASK) != 0U),
               (unsigned int)((Sr & XIICPS_SR_RXOVF_MASK) != 0U),
               (unsigned int)((Sr & XIICPS_SR_TXDV_MASK) != 0U),
               (unsigned int)((Sr & XIICPS_SR_RXDV_MASK) != 0U),
               (unsigned int)((Sr & XIICPS_SR_RXRW_MASK) != 0U));
}

static void dump_i2c_registers(UINTPTR BaseAddress, const char *Tag)
{
    u32 Cr;
    u32 Sr;
    u32 Isr;
    u32 Imr;
    u32 Size;
    u32 Timeout;

    xil_printf("\r\n      I2C register dump: %s, base=0x%08lX\r\n",
               Tag, (unsigned long)BaseAddress);

    Cr      = diag_read32("CR",         BaseAddress + XIICPS_CR_OFFSET);
    Sr      = diag_read32("SR",         BaseAddress + XIICPS_SR_OFFSET);
    Isr     = diag_read32("ISR",        BaseAddress + XIICPS_ISR_OFFSET);
    Size    = diag_read32("TRANS_SIZE", BaseAddress + XIICPS_TRANS_SIZE_OFFSET);
    Timeout = diag_read32("TIME_OUT",   BaseAddress + XIICPS_TIME_OUT_OFFSET);
    Imr     = diag_read32("IMR",        BaseAddress + XIICPS_IMR_OFFSET);

    xil_printf("      CR=0x%08lX SR=0x%08lX ISR=0x%08lX IMR=0x%08lX\r\n",
               (unsigned long)Cr, (unsigned long)Sr,
               (unsigned long)Isr, (unsigned long)Imr);
    xil_printf("      TRANS_SIZE=%lu TIME_OUT=0x%08lX\r\n",
               (unsigned long)Size, (unsigned long)Timeout);
    print_i2c_status_bits(Sr);
}

static int diagnose_i2c1_clock_reset(void)
{
    u32 I2c0Clk;
    u32 I2c1Clk;
    u32 ResetReg;
    int ClockOk;
    int ResetOk;

    diag_step(30U, "CRL_APB clock/reset state for PS I2C controllers");

    I2c0Clk = diag_read32("I2C0_REF_CTRL", FH_CRL_I2C0_REF_CTRL);
    I2c1Clk = diag_read32("I2C1_REF_CTRL", FH_CRL_I2C1_REF_CTRL);
    ResetReg = diag_read32("RST_LPD_IOU2", FH_CRL_RST_LPD_IOU2);

    xil_printf("      I2C0 clock active bit : %u\r\n",
               (unsigned int)((I2c0Clk & FH_I2C_REF_CLKACT_MASK) != 0U));
    xil_printf("      I2C1 clock active bit : %u\r\n",
               (unsigned int)((I2c1Clk & FH_I2C_REF_CLKACT_MASK) != 0U));
    xil_printf("      I2C0 reset asserted   : %u\r\n",
               (unsigned int)((ResetReg & FH_I2C0_RESET_MASK) != 0U));
    xil_printf("      I2C1 reset asserted   : %u\r\n",
               (unsigned int)((ResetReg & FH_I2C1_RESET_MASK) != 0U));

    ClockOk = ((I2c1Clk & FH_I2C_REF_CLKACT_MASK) != 0U);
    ResetOk = ((ResetReg & FH_I2C1_RESET_MASK) == 0U);

    I2c1ResetWasAsserted = ResetOk ? 0 : 1;

    if (!ClockOk) {
        xil_printf("      ERROR: I2C1 reference clock is disabled.\r\n");
        xil_printf("      Unsafe to continue with I2C1 MMIO while its reference clock is off.\r\n");
        return XST_FAILURE;
    }

    if (!ResetOk) {
        xil_printf("      WARNING: I2C1 peripheral reset is asserted.\r\n");
        xil_printf("      D35 will attempt to clear ONLY I2C1 reset bit 10.\r\n");
    } else {
        xil_printf("      PASS: I2C1 clock is active and reset is already released.\r\n");
    }

    return XST_SUCCESS;
}

static int release_i2c1_reset(void)
{
    u32 Before;
    u32 WriteValue;
    u32 After;
    u32 ClockAfter;

    diag_step(35U, "Controlled release of PS I2C1 peripheral reset");

    Before = diag_read32("RST_LPD_IOU2 before", FH_CRL_RST_LPD_IOU2);

    if ((Before & FH_I2C1_RESET_MASK) == 0U) {
        xil_printf("      PASS: I2C1 reset is already RELEASED; no CRL write required.\r\n");
        return XST_SUCCESS;
    }

    I2c1ResetWasAsserted = 1;
    WriteValue = Before & ~FH_I2C1_RESET_MASK;

    xil_printf("      I2C1 reset bit mask   = 0x%08lX\r\n",
               (unsigned long)FH_I2C1_RESET_MASK);
    xil_printf("      Preserving all other RST_LPD_IOU2 bits.\r\n");
    xil_printf("      About to WRITE RST_LPD_IOU2: 0x%08lX -> 0x%08lX\r\n",
               (unsigned long)Before, (unsigned long)WriteValue);
    xil_printf("      If UART stops after this line, the CRL reset-register write is the hang point.\r\n");

    Xil_Out32(FH_CRL_RST_LPD_IOU2, WriteValue);

#if defined(__aarch64__)
    __asm__ volatile("dsb sy" ::: "memory");
    __asm__ volatile("isb" ::: "memory");
#endif

    usleep(10U);

    After = diag_read32("RST_LPD_IOU2 after", FH_CRL_RST_LPD_IOU2);

    if ((After & FH_I2C1_RESET_MASK) != 0U) {
        xil_printf("      FAIL: I2C1 reset bit is still ASSERTED after the write.\r\n");
        xil_printf("      Expected bit 10 to clear; before=0x%08lX after=0x%08lX\r\n",
                   (unsigned long)Before, (unsigned long)After);
        return XST_FAILURE;
    }

    I2c1ResetReleasedByDiagnostic = 1;
    xil_printf("      PASS: I2C1 reset bit is now RELEASED.\r\n");

    if ((After & ~FH_I2C1_RESET_MASK) != (Before & ~FH_I2C1_RESET_MASK)) {
        xil_printf("      WARNING: other RST_LPD_IOU2 bits changed concurrently.\r\n");
        xil_printf("      before(other)=0x%08lX after(other)=0x%08lX\r\n",
                   (unsigned long)(Before & ~FH_I2C1_RESET_MASK),
                   (unsigned long)(After & ~FH_I2C1_RESET_MASK));
    }

    ClockAfter = diag_read32("I2C1_REF_CTRL after reset release", FH_CRL_I2C1_REF_CTRL);
    if ((ClockAfter & FH_I2C_REF_CLKACT_MASK) == 0U) {
        xil_printf("      FAIL: I2C1 reference clock became inactive after reset release.\r\n");
        return XST_FAILURE;
    }

    xil_printf("      PASS: I2C1 reference clock remains active.\r\n");
    xil_printf("      Waiting 100 us before first I2C1 register access.\r\n");
    usleep(100U);

    return XST_SUCCESS;
}

static int init_i2c0(void)
{
    XIicPs_Config *Cfg;
    int Status;

#ifdef SDT
    Cfg = XIicPs_LookupConfig(XPAR_XIICPS_0_BASEADDR);
#else
    Cfg = XIicPs_LookupConfig(XPAR_XIICPS_0_DEVICE_ID);
#endif

    if (Cfg == NULL)
        return XST_FAILURE;

    Status = XIicPs_CfgInitialize(&Iic0, Cfg, Cfg->BaseAddress);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    Status = XIicPs_SelfTest(&Iic0);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    Status = XIicPs_SetSClk(&Iic0, EEPROM_I2C_FREQ_HZ);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    return XST_SUCCESS;
}

static int eeprom_read(u8 Address, u8 *Buffer, u32 Length)
{
    int Status;
    u8 MemoryAddress;

    if (!IicReady)
        return XST_FAILURE;

    if ((Buffer == NULL) || (Length == 0U))
        return XST_FAILURE;

    MemoryAddress = Address;

    if (i2c_wait_idle(&Iic0, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS)
        return XST_FAILURE;

    XIicPs_SetOptions(&Iic0, XIICPS_REP_START_OPTION);

    Status = XIicPs_MasterSendPolled(&Iic0, &MemoryAddress, 1U, EEPROM_ADDR);

    if (Status != XST_SUCCESS) {
        XIicPs_ClearOptions(&Iic0, XIICPS_REP_START_OPTION);
        return XST_FAILURE;
    }

    XIicPs_ClearOptions(&Iic0, XIICPS_REP_START_OPTION);

    Status = XIicPs_MasterRecvPolled(&Iic0, Buffer, Length, EEPROM_ADDR);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    if (i2c_wait_idle(&Iic0, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS)
        return XST_FAILURE;

    return XST_SUCCESS;
}

static void dump_eeprom(void)
{
    u8 Data[EEPROM_DUMP_LINE];
    u32 Address;
    u32 i;

    xil_printf("\r\nEEPROM FULL DUMP\r\n");
    xil_printf("----------------\r\n");

    if (!IicReady) {
        xil_printf("ERROR: I2C0 not initialized.\r\n");
        return;
    }

    for (Address = 0U; Address < EEPROM_SIZE; Address += EEPROM_DUMP_LINE) {
        if (eeprom_read((u8)Address, Data, EEPROM_DUMP_LINE) != XST_SUCCESS) {
            xil_printf("ERROR reading EEPROM address 0x%02X\r\n",
                       (unsigned int)Address);
            return;
        }

        xil_printf("%02X: ", (unsigned int)Address);

        for (i = 0U; i < EEPROM_DUMP_LINE; i++)
            xil_printf("%02X ", (unsigned int)Data[i]);

        xil_printf("\r\n");
    }

    xil_printf("\r\nRESULT: EEPROM FULL DUMP COMPLETE\r\n");
}

static void show_EUI48(void)
{
    u8 Eui[6];

    xil_printf("\r\nFH_Carrier EUI-48\r\n");
    xil_printf("-----------------\r\n");

    if (!IicReady) {
        xil_printf("ERROR: I2C0 not initialized.\r\n");
        return;
    }

    if (eeprom_read(0xFAU, Eui, 6U) != XST_SUCCESS) {
        xil_printf("ERROR: Could not read EUI-48.\r\n");
        return;
    }

    xil_printf("EUI-48: %02X:%02X:%02X:%02X:%02X:%02X\r\n",
               Eui[0], Eui[1], Eui[2], Eui[3], Eui[4], Eui[5]);
}

static int init_pac1944_i2c1(void)
{
    XIicPs_Config *Cfg;
    int Status;
    u32 ActualSclk;
    u32 Sr;

    diag_step(20U, "Locate PS I2C1 configuration in BSP/XSA");

#ifdef SDT
    xil_printf("      Build mode: SDT\r\n");
#ifdef XPAR_XIICPS_1_BASEADDR
    xil_printf("      XPAR_XIICPS_1_BASEADDR = 0x%08lX\r\n",
               (unsigned long)XPAR_XIICPS_1_BASEADDR);
    Cfg = XIicPs_LookupConfig(XPAR_XIICPS_1_BASEADDR);
#elif defined(XPAR_PSU_I2C_1_BASEADDR)
    xil_printf("      Using XPAR_PSU_I2C_1_BASEADDR = 0x%08lX\r\n",
               (unsigned long)XPAR_PSU_I2C_1_BASEADDR);
    Cfg = XIicPs_LookupConfig(XPAR_PSU_I2C_1_BASEADDR);
#else
#error "No I2C1 base-address macro found in xparameters.h"
#endif
#else
    xil_printf("      Build mode: classic BSP\r\n");
#ifdef XPAR_XIICPS_1_DEVICE_ID
    xil_printf("      XPAR_XIICPS_1_DEVICE_ID = %u\r\n",
               (unsigned int)XPAR_XIICPS_1_DEVICE_ID);
    Cfg = XIicPs_LookupConfig(XPAR_XIICPS_1_DEVICE_ID);
#elif defined(XPAR_PSU_I2C_1_DEVICE_ID)
    xil_printf("      Using XPAR_PSU_I2C_1_DEVICE_ID = %u\r\n",
               (unsigned int)XPAR_PSU_I2C_1_DEVICE_ID);
    Cfg = XIicPs_LookupConfig(XPAR_PSU_I2C_1_DEVICE_ID);
#else
#error "No I2C1 device-id macro found in xparameters.h"
#endif
#endif

    if (Cfg == NULL) {
        xil_printf("      FAIL: XIicPs_LookupConfig(I2C1) returned NULL.\r\n");
        return XST_FAILURE;
    }

    xil_printf("      PASS: I2C1 configuration found.\r\n");
    xil_printf("      Cfg->BaseAddress  = 0x%08lX\r\n",
               (unsigned long)Cfg->BaseAddress);
    xil_printf("      Cfg->InputClockHz = %lu Hz\r\n",
               (unsigned long)Cfg->InputClockHz);

    if ((UINTPTR)Cfg->BaseAddress != (UINTPTR)0xFF030000U) {
        xil_printf("      WARNING: expected ZynqMP I2C1 base 0xFF030000, got 0x%08lX.\r\n",
                   (unsigned long)Cfg->BaseAddress);
    }

    if (diagnose_i2c1_clock_reset() != XST_SUCCESS)
        return XST_FAILURE;

    if (release_i2c1_reset() != XST_SUCCESS) {
        xil_printf("      FAIL: unable to place PS I2C1 in released/reset-free state.\r\n");
        xil_printf("      Skipping I2C1 peripheral MMIO to avoid a possible bus hang.\r\n");
        return XST_FAILURE;
    }

    diag_step(40U, "Direct read-only MMIO access to I2C1 after reset release, before driver init");
    xil_printf("      NOTE: if UART stops here, the next I2C1 MMIO read is inaccessible.\r\n");
    dump_i2c_registers((UINTPTR)Cfg->BaseAddress, "before XIicPs_CfgInitialize");

    diag_step(50U, "XIicPs_CfgInitialize(I2C1)");
    xil_printf("      About to call XIicPs_CfgInitialize.\r\n");
    xil_printf("      If UART stops after this line, step into XIicPs_CfgInitialize -> XIicPs_Reset.\r\n");

    Status = XIicPs_CfgInitialize(&Iic1, Cfg, Cfg->BaseAddress);

    xil_printf("      XIicPs_CfgInitialize returned %d\r\n", Status);
    if (Status != XST_SUCCESS) {
        xil_printf("      FAIL: I2C1 CfgInitialize failed.\r\n");
        return XST_FAILURE;
    }

    xil_printf("      PASS: XIicPs_CfgInitialize succeeded.\r\n");
    dump_i2c_registers((UINTPTR)Cfg->BaseAddress, "after XIicPs_CfgInitialize");

#if FH_DIAG_RUN_I2C1_SELFTEST
    diag_step(60U, "XIicPs_SelfTest(I2C1) - destructive register test");
    xil_printf("      About to call XIicPs_SelfTest; it resets/tests controller registers.\r\n");
    Status = XIicPs_SelfTest(&Iic1);
    xil_printf("      XIicPs_SelfTest returned %d\r\n", Status);
    if (Status != XST_SUCCESS) {
        xil_printf("      FAIL: XIicPs_SelfTest failed.\r\n");
        return XST_FAILURE;
    }
    xil_printf("      PASS: XIicPs_SelfTest succeeded.\r\n");
    dump_i2c_registers((UINTPTR)Cfg->BaseAddress, "after XIicPs_SelfTest");
#endif

    diag_step(70U, "Configure I2C1 for PAC1944");

    Status = XIicPs_SetOptions(&Iic1, XIICPS_7_BIT_ADDR_OPTION);
    xil_printf("      Set 7-bit addressing returned %d\r\n", Status);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    Status = XIicPs_ClearOptions(&Iic1, XIICPS_REP_START_OPTION);
    xil_printf("      Clear repeated-start option returned %d\r\n", Status);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    Status = XIicPs_SetSClk(&Iic1, PAC1944_I2C_FREQ_HZ);
    xil_printf("      XIicPs_SetSClk(request=%u Hz) returned %d\r\n",
               (unsigned int)PAC1944_I2C_FREQ_HZ, Status);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    ActualSclk = XIicPs_GetSClk(&Iic1);
    xil_printf("      Actual I2C1 SCL = %lu Hz\r\n", (unsigned long)ActualSclk);

    dump_i2c_registers((UINTPTR)Cfg->BaseAddress, "after options and SCL setup");

    diag_step(80U, "Check physical I2C1 bus idle state");
    Sr = XIicPs_ReadReg(Cfg->BaseAddress, XIICPS_SR_OFFSET);
    xil_printf("      Initial SR = 0x%08lX\r\n", (unsigned long)Sr);
    print_i2c_status_bits(Sr);

    if (i2c_wait_idle(&Iic1, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS) {
        Sr = XIicPs_ReadReg(Cfg->BaseAddress, XIICPS_SR_OFFSET);
        xil_printf("      FAIL: bus remained busy for %u us. SR=0x%08lX\r\n",
                   (unsigned int)I2C_IDLE_TIMEOUT_US, (unsigned long)Sr);
        xil_printf("      Check EMIO IOBUF wiring, XDC pins D2/C2, pull-ups and PAC1944 power.\r\n");
        return XST_FAILURE;
    }

    xil_printf("      PASS: I2C1 bus is idle.\r\n");
    return XST_SUCCESS;
}

static int diagnostic_pac1944_pid_transaction(void)
{
    u8 Reg = PAC_REG_PID;
    u8 Pid = 0U;
    int Status;

    diag_step(90U, "PAC1944 incremental PID transaction on I2C1/EMIO");
    xil_printf("      Slave 7-bit address = 0x%02X; register = 0x%02X\r\n",
               PAC1944_ADDR, PAC_REG_PID);
    xil_printf("      Expected wire address bytes: 0x20 write, 0x21 read.\r\n");

    if (!PacReady) {
        xil_printf("      SKIP: I2C1 controller is not ready.\r\n");
        return XST_FAILURE;
    }

    if (i2c_wait_idle(&Iic1, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS) {
        xil_printf("      FAIL: bus is busy before PAC1944 transaction.\r\n");
        return XST_FAILURE;
    }

    Status = XIicPs_SetOptions(&Iic1, XIICPS_REP_START_OPTION);
    xil_printf("      Enable repeated-start returned %d\r\n", Status);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    xil_printf("      TX phase: sending register 0x%02X to slave 0x%02X ...\r\n",
               Reg, PAC1944_ADDR);
    Status = XIicPs_MasterSendPolled(&Iic1, &Reg, 1U, PAC1944_ADDR);
    xil_printf("      TX phase returned %d\r\n", Status);

    if (Status != XST_SUCCESS) {
        XIicPs_ClearOptions(&Iic1, XIICPS_REP_START_OPTION);
        dump_i2c_registers(Iic1.Config.BaseAddress, "after failed PAC1944 TX");
        xil_printf("      FAIL: no successful register-address write/ACK.\r\n");
        return XST_FAILURE;
    }

    Status = XIicPs_ClearOptions(&Iic1, XIICPS_REP_START_OPTION);
    xil_printf("      Clear repeated-start option before RX returned %d\r\n", Status);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    xil_printf("      RX phase: reading one PID byte ...\r\n");
    Status = XIicPs_MasterRecvPolled(&Iic1, &Pid, 1U, PAC1944_ADDR);
    xil_printf("      RX phase returned %d\r\n", Status);

    if (Status != XST_SUCCESS) {
        dump_i2c_registers(Iic1.Config.BaseAddress, "after failed PAC1944 RX");
        xil_printf("      FAIL: PAC1944 receive transaction failed.\r\n");
        return XST_FAILURE;
    }

    if (i2c_wait_idle(&Iic1, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS) {
        xil_printf("      FAIL: I2C1 remained busy after PID transaction.\r\n");
        return XST_FAILURE;
    }

    xil_printf("      PID = 0x%02X\r\n", Pid);

    if (Pid != 0x6BU) {
        xil_printf("      WARNING: PAC1944 responded, but PID is unexpected.\r\n");
        return XST_FAILURE;
    }

    xil_printf("      PASS: PAC1944 PID transaction completed correctly.\r\n");
    return XST_SUCCESS;
}

static int pac1944_read(u8 RegisterAddress, u8 *Buffer, u32 Length)
{
    int Status;

    if (!PacReady)
        return XST_FAILURE;

    if ((Buffer == NULL) || (Length == 0U))
        return XST_FAILURE;

    if (i2c_wait_idle(&Iic1, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS)
        return XST_FAILURE;

    /*
     * PAC1944 register read over PS I2C1:
     * START + SLA(W) + register + REPEATED START + SLA(R) + data + STOP
     */
    XIicPs_SetOptions(&Iic1, XIICPS_REP_START_OPTION);

    Status = XIicPs_MasterSendPolled(&Iic1,
                                     &RegisterAddress,
                                     1U,
                                     PAC1944_ADDR);

    if (Status != XST_SUCCESS) {
        XIicPs_ClearOptions(&Iic1, XIICPS_REP_START_OPTION);
        return XST_FAILURE;
    }

    XIicPs_ClearOptions(&Iic1, XIICPS_REP_START_OPTION);

    Status = XIicPs_MasterRecvPolled(&Iic1,
                                     Buffer,
                                     Length,
                                     PAC1944_ADDR);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    if (i2c_wait_idle(&Iic1, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS)
        return XST_FAILURE;

    return XST_SUCCESS;
}

static int pac1944_read8(u8 Reg, u8 *Value)
{
    return pac1944_read(Reg, Value, 1U);
}

static int pac1944_read16(u8 Reg, u16 *Value)
{
    u8 Data[2];

    if (Value == NULL)
        return XST_FAILURE;

    if (pac1944_read(Reg, Data, 2U) != XST_SUCCESS)
        return XST_FAILURE;

    *Value = ((u16)Data[0] << 8) | ((u16)Data[1]);

    return XST_SUCCESS;
}

static int pac1944_command(u8 Command)
{
    int Status;
    u8 Data = Command;

    if (!PacReady)
        return XST_FAILURE;

    if (i2c_wait_idle(&Iic1, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS)
        return XST_FAILURE;

    XIicPs_ClearOptions(&Iic1, XIICPS_REP_START_OPTION);

    Status = XIicPs_MasterSendPolled(&Iic1,
                                     &Data,
                                     1U,
                                     PAC1944_ADDR);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    if (i2c_wait_idle(&Iic1, I2C_IDLE_TIMEOUT_US) != XST_SUCCESS)
        return XST_FAILURE;

    return XST_SUCCESS;
}

static int pac1944_refresh_v(void)
{
    if (pac1944_command(PAC_REG_REFRESH_V) != XST_SUCCESS)
        return XST_FAILURE;

    usleep(2000U);
    return XST_SUCCESS;
}

static void test_pac1944_id(void)
{
    u8 Pid;
    u8 Mid;
    u8 Rev;

    xil_printf("\r\nPAC1944 IDENTIFICATION - PS I2C1 / EMIO\r\n");
    xil_printf("---------------------------------------\r\n");

    if (!PacReady) {
        xil_printf("ERROR: PAC1944 PS I2C1/EMIO not initialized.\r\n");
        return;
    }

    xil_printf("Reading PID register 0xFD...\r\n");
    if (pac1944_read8(PAC_REG_PID, &Pid) != XST_SUCCESS) {
        xil_printf("ERROR: no response reading PID from 0x10.\r\n");
        return;
    }

    xil_printf("Reading MID register 0xFE...\r\n");
    if (pac1944_read8(PAC_REG_MID, &Mid) != XST_SUCCESS) {
        xil_printf("ERROR reading MID.\r\n");
        return;
    }

    xil_printf("Reading REV register 0xFF...\r\n");
    if (pac1944_read8(PAC_REG_REV, &Rev) != XST_SUCCESS) {
        xil_printf("ERROR reading REV.\r\n");
        return;
    }

    xil_printf("\r\n");
    xil_printf("I2C address     : 0x10\r\n");
    xil_printf("Product ID      : 0x%02X\r\n", Pid);
    xil_printf("Manufacturer ID : 0x%02X\r\n", Mid);
    xil_printf("Revision ID     : 0x%02X\r\n", Rev);
    xil_printf("\r\n");

    if (Pid == 0x6BU)
        xil_printf("PAC1944 PID     : PASS\r\n");
    else
        xil_printf("PAC1944 PID     : UNEXPECTED\r\n");

    if (Mid == 0x54U)
        xil_printf("Microchip MID   : PASS\r\n");
    else
        xil_printf("Microchip MID   : UNEXPECTED\r\n");

    xil_printf("Silicon revision: 0x%02X\r\n", Rev);
}

static u32 pac_vbus_mV(u16 Raw)
{
    u64 Temp = (u64)Raw * 9000ULL;
    Temp /= 65536ULL;
    return (u32)Temp;
}

static u32 pac_vsense_uV(u16 Raw)
{
    u64 Temp = (u64)Raw * 100000ULL;
    Temp /= 65536ULL;
    return (u32)Temp;
}

/*
 * Current in tenths of a milliamp, calculated directly from the raw
 * VSENSE code to preserve more resolution than the rounded-uV path.
 *
 * I[mA] = VSENSE[uV] / Rshunt[mOhm]
 * I[0.1mA] = Raw * 1,000,000 / (65536 * Rshunt[mOhm])
 */
static u32 pac_current_tenth_mA(u16 Raw, u32 Rshunt_mOhm)
{
    u64 Numerator;
    u64 Denominator;

    if (Rshunt_mOhm == 0U)
        return 0U;

    Numerator = (u64)Raw * 1000000ULL;
    Denominator = 65536ULL * (u64)Rshunt_mOhm;

    Numerator += Denominator / 2ULL;

    return (u32)(Numerator / Denominator);
}

static void test_pac1944_measurements(void)
{
    static const u8 VbusReg[4] = {
        PAC_REG_VBUS1, PAC_REG_VBUS2, PAC_REG_VBUS3, PAC_REG_VBUS4
    };

    static const u8 VsenseReg[4] = {
        PAC_REG_VSENSE1, PAC_REG_VSENSE2, PAC_REG_VSENSE3, PAC_REG_VSENSE4
    };

    /*
     * FH_Carrier schematic shunts / PAC1944 channel mapping:
     *   CH1 -> 1V8       : 2 mOhm
     *   CH2 -> 3V3       : 4 mOhm
     *   CH3 -> 8V rail   : 15 mOhm
     *   CH4 -> 5V        : 2 mOhm
     */
    static const u32 Rshunt_mOhm[4] = {
        2U, 4U, 15U, 2U
    };

    static const char *Rail[4] = {
        "1V8", "3V3", "8V (REG8.3V)", "5V"
    };

    u16 VbusRaw;
    u16 VsenseRaw;
    u16 NegPwrAct;

    u32 Vbus_mV;
    u32 Vsense_uV;
    u32 Current_tenth_mA;

    int Ch;

    xil_printf("\r\nPAC1944 RAIL MEASUREMENTS\r\n");
    xil_printf("-------------------------\r\n");

    if (!PacReady) {
        xil_printf("ERROR: PAC1944 PS I2C1/EMIO not initialized.\r\n");
        return;
    }

    if (pac1944_read16(PAC_REG_NEG_PWR_ACT, &NegPwrAct) != XST_SUCCESS) {
        xil_printf("ERROR reading NEG_PWR_FSR_ACT.\r\n");
        return;
    }

    xil_printf("NEG_PWR_FSR_ACT = 0x%04X\r\n", NegPwrAct);

    if (NegPwrAct != 0x0000U) {
        xil_printf("\r\nWARNING: PAC1944 is not using default FSR.\r\n");
        xil_printf("Only raw values will be considered reliable.\r\n");
    }

    if (pac1944_refresh_v() != XST_SUCCESS) {
        xil_printf("ERROR executing REFRESH_V.\r\n");
        return;
    }

    for (Ch = 0; Ch < 4; Ch++) {
        if (pac1944_read16(VbusReg[Ch], &VbusRaw) != XST_SUCCESS) {
            xil_printf("ERROR reading VBUS channel %d\r\n", Ch + 1);
            return;
        }

        if (pac1944_read16(VsenseReg[Ch], &VsenseRaw) != XST_SUCCESS) {
            xil_printf("ERROR reading VSENSE channel %d\r\n", Ch + 1);
            return;
        }

        xil_printf("\r\nCH%d - %s\r\n", Ch + 1, Rail[Ch]);
        xil_printf("  VBUS raw   : 0x%04X\r\n", VbusRaw);
        xil_printf("  VSENSE raw : 0x%04X\r\n", VsenseRaw);

        if (NegPwrAct == 0x0000U) {
            Vbus_mV = pac_vbus_mV(VbusRaw);
            Vsense_uV = pac_vsense_uV(VsenseRaw);
            Current_tenth_mA = pac_current_tenth_mA(VsenseRaw,
                                                    Rshunt_mOhm[Ch]);

            xil_printf("  VBUS       : %u mV\r\n", Vbus_mV);
            xil_printf("  VSENSE     : %u uV\r\n", Vsense_uV);
            xil_printf("  Current    : %u.%u mA\r\n",
                       Current_tenth_mA / 10U,
                       Current_tenth_mA % 10U);
        }
    }

    xil_printf("\r\nPAC1944 measurement read complete.\r\n");
}


/* ------------------------------------------------------------------------- */
/* FH_Sen4K / GMAX3412-A diagnostics                                        */
/* ------------------------------------------------------------------------- */

static int gmax_pl_ready(void)
{
    u32 PcapStatus = Xil_In32(FH_CSU_PCAP_STATUS);

    return ((PcapStatus & FH_PCAP_PL_READY_MASK) == FH_PCAP_PL_READY_MASK);
}

static void gmax_decode_ctrl(u32 Ctrl)
{
    xil_printf("  PWR_EN       : %u\r\n", (unsigned int)((Ctrl & GMAX_CTRL_PWR_EN) != 0U));
    xil_printf("  CLK_EN       : %u\r\n", (unsigned int)((Ctrl & GMAX_CTRL_CLK_EN) != 0U));
    xil_printf("  SYS_RST_N    : %u\r\n", (unsigned int)((Ctrl & GMAX_CTRL_SYS_RST_N) != 0U));
    xil_printf("  CCI_EN       : %u (%s)\r\n",
               (unsigned int)((Ctrl & GMAX_CTRL_CCI_EN) != 0U),
               (Ctrl & GMAX_CTRL_CCI_EN) ? "I2C" : "SPI");
    xil_printf("  XCE/SLAMODE  : %u\r\n", (unsigned int)((Ctrl & GMAX_CTRL_XCE_SLAMODE) != 0U));
    xil_printf("  TEXP1        : %u\r\n", (unsigned int)((Ctrl & GMAX_CTRL_TEXP1) != 0U));
    xil_printf("  TEXP2        : %u\r\n", (unsigned int)((Ctrl & GMAX_CTRL_TEXP2) != 0U));
    xil_printf("  SPI_SCK      : %u\r\n", (unsigned int)((Ctrl & GMAX_CTRL_SPI_SCK) != 0U));
    xil_printf("  SPI_SDI      : %u\r\n", (unsigned int)((Ctrl & GMAX_CTRL_SPI_SDI) != 0U));
    xil_printf("  RXDBG slot   : %u\r\n",
               (unsigned int)((Ctrl & GMAX_CTRL_RXDBG_INDEX_MASK) >> GMAX_CTRL_RXDBG_INDEX_SHIFT));
    xil_printf("  RXDBG lane   : D%u\r\n",
               (unsigned int)((Ctrl & GMAX_CTRL_RXDBG_LANE) != 0U));
    xil_printf("  RXDBG freeze : %u\r\n",
               (unsigned int)((Ctrl & GMAX_CTRL_RXDBG_FREEZE) != 0U));
}

static int gmax_ctrl_write(u32 Value)
{
#if FH_GMAX_GPIO_AVAILABLE
    if (!GmaxControlReady)
        return XST_FAILURE;

    Value &= GMAX_CTRL_ALL_MASK;
    Xil_Out32(FH_GMAX_GPIO_BASEADDR + FH_AXI_GPIO_CH1_DATA, Value);
    GmaxCtrlShadow = Value;
    return XST_SUCCESS;
#else
    (void)Value;
    return XST_FAILURE;
#endif
}

static int gmax_ctrl_update(u32 SetMask, u32 ClearMask)
{
    u32 Value = GmaxCtrlShadow;

    Value &= ~ClearMask;
    Value |= SetMask;
    return gmax_ctrl_write(Value);
}

static u32 gmax_status_read(void)
{
#if FH_GMAX_GPIO_AVAILABLE
    if (!GmaxControlReady)
        return 0U;

    return Xil_In32(FH_GMAX_GPIO_BASEADDR + FH_AXI_GPIO_CH2_DATA);
#else
    return 0U;
#endif
}

static u16 gmax_training_result_from_status(u32 Status)
{
    return (u16)((Status & GMAX_STATUS_TRAINING_RESULT_MASK) >>
                 GMAX_STATUS_TRAINING_SHIFT);
}

static int gmax_training_done_from_status(u32 Status)
{
    return ((Status & GMAX_STATUS_TRAINING_DONE_MASK) != 0U);
}

static unsigned int gmax_count_training_lanes(u16 Result)
{
    unsigned int Count = 0U;
    unsigned int Lane;

    for (Lane = 0U; Lane < 16U; Lane++) {
        if ((Result & (u16)(1U << Lane)) != 0U)
            Count++;
    }

    return Count;
}

static void gmax_print_training_status(u32 Status)
{
    u16 Result = gmax_training_result_from_status(Status);
    int Done = gmax_training_done_from_status(Status);
    unsigned int Lane;

    xil_printf("  RX status raw   : 0x%08lX\r\n", (unsigned long)Status);
    xil_printf("  training_done   : %u\r\n", (unsigned int)Done);
    xil_printf("  training_result : 0x%04X (%u/16 lanes PASS)\r\n",
               (unsigned int)Result, gmax_count_training_lanes(Result));

    if (Done && (Result == 0xFFFFU)) {
        xil_printf("  RX training     : PASS - all 16 lanes locked\r\n");
    } else if (Done) {
        xil_printf("  RX training     : incomplete attempt; RTL will retry automatically\r\n");
        xil_printf("  Lanes not PASS  :");
        for (Lane = 0U; Lane < 16U; Lane++) {
            if ((Result & (u16)(1U << Lane)) == 0U)
                xil_printf(" %u", Lane);
        }
        xil_printf("\r\n");
    } else {
        xil_printf("  RX training     : not complete (not started or currently running)\r\n");
    }
}

static void gmax_print_failed_lanes(u16 Result)
{
    unsigned int Lane;
    int Any = 0;

    xil_printf("    Failed lanes  :");
    for (Lane = 0U; Lane < 16U; Lane++) {
        if ((Result & (u16)(1U << Lane)) == 0U) {
            xil_printf(" %u", Lane);
            Any = 1;
        }
    }
    if (!Any)
        xil_printf(" none");
    xil_printf("\r\n");
}

static int gmax_wait_for_training(u32 TimeoutUs)
{
    u32 Remaining = TimeoutUs;
    u32 Status = 0U;
    u16 Result = 0U;
    u16 AttemptLog[GMAX_TRAINING_LOG_DEPTH];
    u32 AttemptCount = 0U;
    u32 LoggedCount = 0U;
    int PrevDone = 0;
    int Done;
    int SawActivity = 0;
    u16 BestCompletedResult = 0U;
    unsigned int BestCompletedCount = 0U;
    u16 BestObservedResult = 0U;
    unsigned int BestObservedCount = 0U;
    unsigned int Count;
    u32 i;

    xil_printf("Waiting up to %u ms for PL receiver training ...\r\n",
               (unsigned int)(TimeoutUs / 1000U));
    xil_printf("  v16 fast polling: %u us; completed attempts are logged without UART traffic.\r\n",
               (unsigned int)GMAX_TRAINING_POLL_US);

    /*
     * The adapter leaves training_done high during its retry wait, but that
     * interval is much shorter than the old 10-ms software poll.  Polling at
     * 10 us lets software observe completed attempts while keeping UART output
     * out of this timing-sensitive loop.
     */
    while (Remaining > 0U) {
        Status = gmax_status_read();
        Result = gmax_training_result_from_status(Status);
        Done = gmax_training_done_from_status(Status);
        Count = gmax_count_training_lanes(Result);

        if ((Result != 0U) || Done)
            SawActivity = 1;

        if (Count > BestObservedCount) {
            BestObservedCount = Count;
            BestObservedResult = Result;
        }

        /* Count each completed attempt once, on training_done 0 -> 1. */
        if (Done && !PrevDone) {
            AttemptCount++;
            if (LoggedCount < GMAX_TRAINING_LOG_DEPTH) {
                AttemptLog[LoggedCount] = Result;
                LoggedCount++;
            }

            if (Count > BestCompletedCount) {
                BestCompletedCount = Count;
                BestCompletedResult = Result;
            }

            if (Result == 0xFFFFU) {
                xil_printf("  Training attempt %lu completed: 0xFFFF (16/16 lanes PASS)\r\n",
                           (unsigned long)AttemptCount);
                gmax_print_training_status(Status);
                return XST_SUCCESS;
            }
        }

        PrevDone = Done;

        if (Remaining <= GMAX_TRAINING_POLL_US)
            break;

        usleep(GMAX_TRAINING_POLL_US);
        Remaining -= GMAX_TRAINING_POLL_US;
    }

    Status = gmax_status_read();

    xil_printf("\r\nPL receiver training observation summary\r\n");
    xil_printf("----------------------------------------\r\n");
    xil_printf("  Completed attempts observed : %lu\r\n",
               (unsigned long)AttemptCount);

    for (i = 0U; i < LoggedCount; i++) {
        u16 Logged = AttemptLog[i];
        xil_printf("  Attempt %lu: result 0x%04X (%u/16 lanes PASS)\r\n",
                   (unsigned long)(i + 1U),
                   (unsigned int)Logged,
                   gmax_count_training_lanes(Logged));
        if (Logged != 0xFFFFU)
            gmax_print_failed_lanes(Logged);
    }

    if (AttemptCount > LoggedCount) {
        xil_printf("  NOTE: %lu additional completed attempts were observed but not logged\r\n",
                   (unsigned long)(AttemptCount - LoggedCount));
        xil_printf("        (log depth = %u; polling continued normally).\r\n",
                   (unsigned int)GMAX_TRAINING_LOG_DEPTH);
    }

    if (AttemptCount != 0U) {
        xil_printf("  Best completed result       : 0x%04X (%u/16 lanes PASS)\r\n",
                   (unsigned int)BestCompletedResult,
                   BestCompletedCount);
        if (BestCompletedResult != 0xFFFFU)
            gmax_print_failed_lanes(BestCompletedResult);
    } else {
        xil_printf("  No completed training attempt was observed.\r\n");
    }

    xil_printf("  Best result seen in any poll: 0x%04X (%u/16 lanes PASS)\r\n",
               (unsigned int)BestObservedResult,
               BestObservedCount);

    if (!SawActivity) {
        xil_printf("  Activity diagnosis          : no training_result bits and no training_done pulse seen.\r\n");
        xil_printf("                                Investigate clk_rxg / receiver reset / training FSM.\r\n");
    } else if (AttemptCount == 0U) {
        xil_printf("  Activity diagnosis          : receiver activity was seen, but no completion pulse was captured.\r\n");
    } else {
        xil_printf("  Activity diagnosis          : training FSM is completing attempts and retrying.\r\n");
        xil_printf("                                Investigate the failing lane/alignment masks above.\r\n");
    }

    xil_printf("\r\nFinal instantaneous status:\r\n");
    gmax_print_training_status(Status);
    xil_printf("  RX training     : TIMEOUT - did not reach 0xFFFF within %u ms\r\n",
               (unsigned int)(TimeoutUs / 1000U));
    return XST_FAILURE;
}

static void gmax_show_training_status(void)
{
    u32 Status;

    xil_printf("\r\nGMAX3412 PL RECEIVER TRAINING STATUS\r\n");
    xil_printf("-------------------------------------\r\n");

    if (!GmaxControlReady) {
        xil_printf("ERROR: GMAX control/status AXI GPIO is not initialized.\r\n");
        return;
    }

    Status = gmax_status_read();
    gmax_print_training_status(Status);

    if (!GmaxStreamEnabled)
        xil_printf("  NOTE: firmware state says STREAM_EN is not currently enabled.\r\n");
}

static int gmax_iic_wait_idle(u32 TimeoutUs)
{
#if FH_GMAX_IIC_AVAILABLE
    const u32 PollUs = 10U;

    while ((XIic_ReadReg(FH_GMAX_IIC_BASEADDR, XIIC_SR_REG_OFFSET) &
            XIIC_SR_BUS_BUSY_MASK) != 0U) {
        if (TimeoutUs <= PollUs)
            return XST_FAILURE;
        usleep(PollUs);
        TimeoutUs -= PollUs;
    }

    return XST_SUCCESS;
#else
    (void)TimeoutUs;
    return XST_FAILURE;
#endif
}

static int gmax_iic_driver_init(void)
{
#if FH_GMAX_IIC_AVAILABLE
    XIic_Config *Cfg;
    int Status;

    if (!gmax_pl_ready())
        return XST_FAILURE;

#ifdef SDT
    Cfg = XIic_LookupConfig(FH_GMAX_IIC_BASEADDR);
#elif defined(XPAR_XIIC_0_DEVICE_ID)
    Cfg = XIic_LookupConfig(XPAR_XIIC_0_DEVICE_ID);
#else
    xil_printf("  AXI IIC init : FAIL - no SDT base-address or legacy device ID\r\n");
    GmaxIicReady = 0;
    return XST_FAILURE;
#endif

    if (Cfg == NULL) {
        xil_printf("  AXI IIC init : FAIL - XIic_LookupConfig returned NULL\r\n");
        GmaxIicReady = 0;
        return XST_FAILURE;
    }

    xil_printf("  AXI IIC cfg  : base=0x%08lX, 10-bit=%d, GPO width=%u\r\n",
               (unsigned long)Cfg->BaseAddress,
               Cfg->Has10BitAddr,
               (unsigned int)Cfg->GpOutWidth);

    if ((UINTPTR)Cfg->BaseAddress != FH_GMAX_IIC_BASEADDR) {
        xil_printf("  AXI IIC init : FAIL - BSP base does not match xparameters mapping\r\n");
        GmaxIicReady = 0;
        return XST_FAILURE;
    }

    Status = XIic_CfgInitialize(&GmaxIic, Cfg, Cfg->BaseAddress);
    if (Status != XST_SUCCESS) {
        xil_printf("  AXI IIC init : FAIL - XIic_CfgInitialize returned %d\r\n", Status);
        GmaxIicReady = 0;
        return XST_FAILURE;
    }

    GmaxIicReady = 1;
    return XST_SUCCESS;
#else
    GmaxIicReady = 0;
    return XST_FAILURE;
#endif
}

static void gmax_iic_recover(void)
{
#if FH_GMAX_IIC_AVAILABLE
    if (!gmax_pl_ready())
        return;

    if (GmaxIicReady)
        XIic_Reset(&GmaxIic);
    else
        XIic_WriteReg(FH_GMAX_IIC_BASEADDR, XIIC_RESETR_OFFSET, XIIC_RESET_MASK);

    usleep(100U);
    (void)gmax_iic_wait_idle(GMAX_IIC_IDLE_TIMEOUT_US);
#endif
}

static int gmax_iic_reset(void)
{
#if FH_GMAX_IIC_AVAILABLE
    if (!gmax_pl_ready())
        return XST_FAILURE;

    if (!GmaxIicReady) {
        if (gmax_iic_driver_init() != XST_SUCCESS)
            return XST_FAILURE;
    }

    XIic_Reset(&GmaxIic);
    usleep(100U);

    if (gmax_iic_wait_idle(GMAX_IIC_IDLE_TIMEOUT_US) != XST_SUCCESS)
        return XST_FAILURE;

    return XST_SUCCESS;
#else
    return XST_FAILURE;
#endif
}

static int gmax_hw_init_safe(void)
{
#if FH_GMAX_GPIO_AVAILABLE
    u32 PcapStatus = Xil_In32(FH_CSU_PCAP_STATUS);

    xil_printf("\r\nFH_Sen4K/GMAX_A PL CONTROL INITIALIZATION\r\n");
    xil_printf("-----------------------------------------\r\n");
    xil_printf("  PCAP status : 0x%08lX\r\n", (unsigned long)PcapStatus);
    xil_printf("  GPIO base   : 0x%08lX\r\n", (unsigned long)FH_GMAX_GPIO_BASEADDR);
    if (FH_GMAX_GPIO_BASEADDR != FH_GMAX_GPIO_EXPECTED_BASEADDR)
        xil_printf("  WARNING     : expected current GMAX GPIO base 0x%08lX\r\n",
                   (unsigned long)FH_GMAX_GPIO_EXPECTED_BASEADDR);
#if FH_GMAX_IIC_AVAILABLE
    xil_printf("  AXI IIC base: 0x%08lX\r\n", (unsigned long)FH_GMAX_IIC_BASEADDR);
    if (FH_GMAX_IIC_BASEADDR != FH_GMAX_IIC_EXPECTED_BASEADDR)
        xil_printf("  WARNING     : expected current GMAX AXI IIC base 0x%08lX\r\n",
                   (unsigned long)FH_GMAX_IIC_EXPECTED_BASEADDR);
#else
    xil_printf("  AXI IIC     : UNAVAILABLE in xparameters.h\r\n");
#endif

    if (!gmax_pl_ready()) {
        xil_printf("  FAIL: PL is not DONE+EOS; GMAX AXI slaves will not be accessed.\r\n");
        GmaxControlReady = 0;
        return XST_FAILURE;
    }

    /*
     * Channel 1 = 15 outputs: 9 camera controls + 6 V16 RX-debug selectors.
     * Channel 2 = 32 status inputs: legacy SDO/training bits plus V16 RX debug.
     */
    Xil_Out32(FH_GMAX_GPIO_BASEADDR + FH_AXI_GPIO_CH1_TRI, 0x00000000U);
    Xil_Out32(FH_GMAX_GPIO_BASEADDR + FH_AXI_GPIO_CH2_TRI,
              GMAX_STATUS_CH2_INPUT_MASK);

    GmaxControlReady = 1;
    GmaxIicReady = 0;
    GmaxPowered = 0;
    GmaxResetReleased = 0;
    GmaxClockEnabled = 0;
    GmaxConfigLoaded = 0;
    GmaxInternalPowered = 0;
    GmaxPhyCalibrated = 0;
    GmaxStreamEnabled = 0;

    if (gmax_ctrl_write(GMAX_CTRL_SAFE_I2C) != XST_SUCCESS) {
        GmaxControlReady = 0;
        xil_printf("  FAIL: unable to write safe GPIO state.\r\n");
        return XST_FAILURE;
    }

    xil_printf("  GPIO state  : 0x%03lX SAFE/OFF, I2C selected, address 0x10\r\n",
               (unsigned long)GmaxCtrlShadow);

#if FH_GMAX_IIC_AVAILABLE
    if (gmax_iic_driver_init() != XST_SUCCESS) {
        xil_printf("  WARNING: AXI IIC driver/config initialization failed. GPIO remains SAFE/OFF.\r\n");
    } else if (gmax_iic_reset() != XST_SUCCESS) {
        xil_printf("  WARNING: AXI IIC reset/idle check failed. GPIO remains SAFE/OFF.\r\n");
    } else {
        xil_printf("  AXI IIC     : SDT/config init + reset + bus-idle check PASS\r\n");
    }
#endif

    return XST_SUCCESS;
#else
    xil_printf("\r\nFH_Sen4K/GMAX_A control is unavailable in this BSP.\r\n");
    xil_printf("Expected an AXI GPIO instance for axi_gpio_gmax_a_ctrl.\r\n");
    GmaxControlReady = 0;
    return XST_FAILURE;
#endif
}

static void gmax_show_status(void)
{
    u32 Ctrl;
    u32 Status;
    u32 Tri1;
    u32 Tri2;

    xil_printf("\r\nFH_Sen4K / GMAX3412-A STATUS\r\n");
    xil_printf("----------------------------\r\n");
    xil_printf("  GPIO available : %s\r\n", FH_GMAX_GPIO_AVAILABLE ? "YES" : "NO");
    xil_printf("  AXI IIC avail. : %s\r\n", FH_GMAX_IIC_AVAILABLE ? "YES" : "NO");
    xil_printf("  AXI IIC ready  : %s\r\n", GmaxIicReady ? "YES" : "NO");
    xil_printf("  Control ready  : %s\r\n", GmaxControlReady ? "YES" : "NO");
    xil_printf("  Commanded power: %s\r\n", GmaxPowered ? "ON" : "OFF");
    xil_printf("  Reset released : %s\r\n", GmaxResetReleased ? "YES" : "NO");
    xil_printf("  Clock enabled  : %s\r\n", GmaxClockEnabled ? "YES" : "NO");
    xil_printf("  10b config     : %s\r\n", GmaxConfigLoaded ? "LOADED" : "NO/UNKNOWN");
    xil_printf("  Internal power : %s\r\n", GmaxInternalPowered ? "ON" : "OFF/UNKNOWN");
    xil_printf("  PHY calibrated : %s\r\n", GmaxPhyCalibrated ? "YES" : "NO/UNKNOWN");
    xil_printf("  TP recovery    : %s\r\n", GmaxPatternRecoveryRequired ? "REQUIRED (O then A)" : "NO");
    xil_printf("  STREAM_EN      : %s\r\n", GmaxStreamEnabled ? "ON" : "OFF/UNKNOWN");

#if FH_GMAX_GPIO_AVAILABLE
    if (!GmaxControlReady) {
        xil_printf("  Run/allow safe initialization before reading AXI GPIO.\r\n");
        return;
    }

    Ctrl = Xil_In32(FH_GMAX_GPIO_BASEADDR + FH_AXI_GPIO_CH1_DATA) & GMAX_CTRL_ALL_MASK;
    Status = gmax_status_read();
    Tri1 = Xil_In32(FH_GMAX_GPIO_BASEADDR + FH_AXI_GPIO_CH1_TRI);
    Tri2 = Xil_In32(FH_GMAX_GPIO_BASEADDR + FH_AXI_GPIO_CH2_TRI);

    xil_printf("  GPIO base      : 0x%08lX\r\n", (unsigned long)FH_GMAX_GPIO_BASEADDR);
    xil_printf("  CH1 DATA       : 0x%03lX\r\n", (unsigned long)Ctrl);
    xil_printf("  CH1 TRI        : 0x%08lX (informational; IP has fixed output direction)\r\n",
               (unsigned long)Tri1);
    xil_printf("  CH2 TRI        : 0x%08lX (informational; IP has fixed input direction)\r\n",
               (unsigned long)Tri2);
    xil_printf("  SDO_TDIG       : %u\r\n",
               (unsigned int)((Status & GMAX_STATUS_SDO_TDIG) != 0U));
    gmax_print_training_status(Status);
    gmax_decode_ctrl(Ctrl);
#endif

#if FH_GMAX_IIC_AVAILABLE
    xil_printf("  AXI IIC base   : 0x%08lX\r\n", (unsigned long)FH_GMAX_IIC_BASEADDR);
    xil_printf("  AXI IIC SR     : 0x%08lX\r\n",
               (unsigned long)XIic_ReadReg(FH_GMAX_IIC_BASEADDR, XIIC_SR_REG_OFFSET));
#endif
}

static int gmax_power_up_i2c(void)
{
    xil_printf("\r\nFH_Sen4K SAFE POWER-UP - I2C MODE\r\n");
    xil_printf("---------------------------------\r\n");

    if (!GmaxControlReady) {
        if (gmax_hw_init_safe() != XST_SUCCESS)
            return XST_FAILURE;
    }

    /* Never hard-cycle the camera while its internal supplies/stream are active. */
    if (GmaxInternalPowered || GmaxStreamEnabled) {
        xil_printf("REFUSED: GMAX internal power/stream state is active.\r\n");
        xil_printf("Use X for controlled internal power-down or O for full power-down first.\r\n");
        return XST_FAILURE;
    }

    /* Start from a deterministic powered-off state. */
    if (gmax_ctrl_write(GMAX_CTRL_SAFE_I2C) != XST_SUCCESS)
        return XST_FAILURE;

    GmaxPowered = 0;
    GmaxResetReleased = 0;
    GmaxClockEnabled = 0;
    GmaxConfigLoaded = 0;
    GmaxInternalPowered = 0;
    GmaxPhyCalibrated = 0;
    GmaxStreamEnabled = 0;
    usleep(1000U);

    xil_printf("  [1] CCI_EN=1, SLAMODE=0, SYS_RST_N=0, CLK_EN=0\r\n");
    xil_printf("  [2] PWR_EN -> 1; waiting %u ms for local LM3880 rail sequence\r\n",
               (unsigned int)(GMAX_RAIL_SETTLE_US / 1000U));
    if (gmax_ctrl_update(GMAX_CTRL_PWR_EN, 0U) != XST_SUCCESS)
        return XST_FAILURE;
    GmaxPowered = 1;
    usleep(GMAX_RAIL_SETTLE_US);

    /*
     * This 100 ms wait is deliberately much longer than the board's local
     * sequencer interval and therefore also covers the datasheet requirement
     * that SYS_RST_N is not released until >=0.5 ms after VDDPIX reaches 90%.
     */
    xil_printf("  [3] SYS_RST_N -> 1\r\n");
    if (gmax_ctrl_update(GMAX_CTRL_SYS_RST_N, 0U) != XST_SUCCESS)
        return XST_FAILURE;
    GmaxResetReleased = 1;
    usleep(GMAX_RESET_TO_CLK_US);

    /* GMAX3412 requires >=2 us from reset release to CLK_REF start. */
    xil_printf("  [4] waited %u us (>2 us minimum); CLK_EN -> 1\r\n",
               (unsigned int)GMAX_RESET_TO_CLK_US);
    if (gmax_ctrl_update(GMAX_CTRL_CLK_EN, 0U) != XST_SUCCESS)
        return XST_FAILURE;
    GmaxClockEnabled = 1;
    usleep(GMAX_CLK_SETTLE_US);

#if FH_GMAX_IIC_AVAILABLE
    if (gmax_iic_reset() != XST_SUCCESS) {
        xil_printf("  WARNING: AXI IIC did not return to idle after reset.\r\n");
        return XST_FAILURE;
    }
#endif

    xil_printf("  [5] 40 MHz local oscillator allowed %u ms to stabilize\r\n",
               (unsigned int)(GMAX_CLK_SETTLE_US / 1000U));
    xil_printf("  RESULT: external power/reset/clock sequence complete.\r\n");
    xil_printf("  NOTE: this step only controls external FH_Sen4K power/reset/CLK_REF.\r\n");
    xil_printf("        It does not write GMAX PWR_UP_EN, CH_CLK_EN or STREAM_EN.\r\n");
    return XST_SUCCESS;
}

static int gmax_internal_power_down(void);

static void gmax_power_down(void)
{
    xil_printf("\r\nFH_Sen4K GRACEFUL POWER-DOWN\r\n");
    xil_printf("-----------------------------\r\n");

    if (!GmaxControlReady) {
        xil_printf("Control GPIO is not initialized; nothing was written.\r\n");
        return;
    }

    /* Stop any trigger request immediately. */
    (void)gmax_ctrl_update(GMAX_CTRL_CCI_EN,
                           GMAX_CTRL_XCE_SLAMODE |
                           GMAX_CTRL_TEXP1 |
                           GMAX_CTRL_TEXP2 |
                           GMAX_CTRL_SPI_SCK |
                           GMAX_CTRL_SPI_SDI);

    /*
     * If the sensor is externally powered and communicable, attempt the
     * datasheet internal power-down first. Failure does not prevent the
     * subsequent fail-safe external reset/power removal.
     */
    if (GmaxPowered && GmaxResetReleased && GmaxClockEnabled) {
        if (gmax_internal_power_down() != XST_SUCCESS)
            xil_printf("  WARNING: internal GMAX power-down was not confirmed; continuing external OFF.\r\n");
    }

    xil_printf("  SYS_RST_N -> 0\r\n");
    (void)gmax_ctrl_update(0U, GMAX_CTRL_SYS_RST_N);
    GmaxResetReleased = 0;
    usleep(10U);

    xil_printf("  CLK_EN -> 0\r\n");
    (void)gmax_ctrl_update(0U, GMAX_CTRL_CLK_EN);
    GmaxClockEnabled = 0;
    usleep(1000U);

    xil_printf("  PWR_EN -> 0\r\n");
    (void)gmax_ctrl_update(0U, GMAX_CTRL_PWR_EN);
    GmaxPowered = 0;
    usleep(GMAX_POWER_DOWN_SETTLE_US);

    GmaxConfigLoaded = 0;
    GmaxInternalPowered = 0;
    GmaxPhyCalibrated = 0;
    GmaxStreamEnabled = 0;

    (void)gmax_ctrl_write(GMAX_CTRL_SAFE_I2C);
    xil_printf("  RESULT: camera control returned to SAFE/OFF state 0x%03lX.\r\n",
               (unsigned long)GmaxCtrlShadow);
}

static int gmax_require_powered(void)
{
    if (!GmaxControlReady) {
        xil_printf("ERROR: GMAX control GPIO is not initialized.\r\n");
        return XST_FAILURE;
    }

    if (!GmaxPowered || !GmaxResetReleased || !GmaxClockEnabled) {
        xil_printf("ERROR: FH_Sen4K is not in the commanded powered/reset-released/clocked state.\r\n");
        xil_printf("Run FH_Sen4K submenu option 2 first.\r\n");
        return XST_FAILURE;
    }

    return XST_SUCCESS;
}

static int gmax_select_i2c_address(u8 SlaveAddress)
{
    u32 SetMask = GMAX_CTRL_CCI_EN;
    u32 ClearMask = GMAX_CTRL_SPI_SCK | GMAX_CTRL_SPI_SDI;

    if (SlaveAddress == GMAX_I2C_ADDR_0) {
        ClearMask |= GMAX_CTRL_XCE_SLAMODE;
    } else if (SlaveAddress == GMAX_I2C_ADDR_1) {
        SetMask |= GMAX_CTRL_XCE_SLAMODE;
    } else {
        return XST_FAILURE;
    }

    if (gmax_ctrl_update(SetMask, ClearMask) != XST_SUCCESS)
        return XST_FAILURE;

    usleep(10U);
    return XST_SUCCESS;
}

static int gmax_i2c_read8_at(u8 SlaveAddress, u16 RegisterAddress, u8 *Value)
{
#if FH_GMAX_IIC_AVAILABLE
    u8 AddressBytes[2];
    unsigned Sent;
    unsigned Received;

    if (Value == NULL)
        return XST_FAILURE;

    if (gmax_require_powered() != XST_SUCCESS)
        return XST_FAILURE;

    if (gmax_select_i2c_address(SlaveAddress) != XST_SUCCESS)
        return XST_FAILURE;

    if (gmax_iic_wait_idle(GMAX_IIC_IDLE_TIMEOUT_US) != XST_SUCCESS) {
        xil_printf("I2C ERROR: AXI IIC bus busy before transaction.\r\n");
        return XST_FAILURE;
    }

    AddressBytes[0] = (u8)(RegisterAddress >> 8);
    AddressBytes[1] = (u8)(RegisterAddress & 0xFFU);

    Sent = XIic_Send(FH_GMAX_IIC_BASEADDR,
                     SlaveAddress,
                     AddressBytes,
                     2U,
                     XIIC_REPEATED_START);
    if (Sent != 2U) {
        xil_printf("I2C ERROR: register-address phase sent %u/2 bytes.\r\n", Sent);
        gmax_iic_recover();
        return XST_FAILURE;
    }

    Received = XIic_Recv(FH_GMAX_IIC_BASEADDR,
                         SlaveAddress,
                         Value,
                         1U,
                         XIIC_STOP);
    if (Received != 1U) {
        xil_printf("I2C ERROR: receive phase returned %u/1 bytes.\r\n", Received);
        gmax_iic_recover();
        return XST_FAILURE;
    }

    if (gmax_iic_wait_idle(GMAX_IIC_IDLE_TIMEOUT_US) != XST_SUCCESS) {
        xil_printf("I2C ERROR: bus did not return idle after read.\r\n");
        gmax_iic_recover();
        return XST_FAILURE;
    }

    return XST_SUCCESS;
#else
    (void)SlaveAddress;
    (void)RegisterAddress;
    (void)Value;
    xil_printf("ERROR: no AXI IIC base-address macro found in xparameters.h.\r\n");
    return XST_FAILURE;
#endif
}

static int gmax_i2c_write8_at(u8 SlaveAddress, u16 RegisterAddress, u8 Value)
{
#if FH_GMAX_IIC_AVAILABLE
    u8 Tx[3];
    unsigned Sent;

    if (gmax_require_powered() != XST_SUCCESS)
        return XST_FAILURE;

    if (gmax_select_i2c_address(SlaveAddress) != XST_SUCCESS)
        return XST_FAILURE;

    if (gmax_iic_wait_idle(GMAX_IIC_IDLE_TIMEOUT_US) != XST_SUCCESS) {
        xil_printf("I2C ERROR: AXI IIC bus busy before write.\r\n");
        return XST_FAILURE;
    }

    Tx[0] = (u8)(RegisterAddress >> 8);
    Tx[1] = (u8)(RegisterAddress & 0xFFU);
    Tx[2] = Value;

    Sent = XIic_Send(FH_GMAX_IIC_BASEADDR,
                     SlaveAddress,
                     Tx,
                     3U,
                     XIIC_STOP);
    if (Sent != 3U) {
        xil_printf("I2C ERROR: write phase sent %u/3 bytes.\r\n", Sent);
        gmax_iic_recover();
        return XST_FAILURE;
    }

    if (gmax_iic_wait_idle(GMAX_IIC_IDLE_TIMEOUT_US) != XST_SUCCESS) {
        xil_printf("I2C ERROR: bus did not return idle after write.\r\n");
        gmax_iic_recover();
        return XST_FAILURE;
    }

    return XST_SUCCESS;
#else
    (void)SlaveAddress;
    (void)RegisterAddress;
    (void)Value;
    return XST_FAILURE;
#endif
}

static int gmax_i2c_rmw8(u16 RegisterAddress, u8 SetMask, u8 ClearMask, u8 *NewValue)
{
    u8 Before;
    u8 After;
    u8 Readback;

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, RegisterAddress, &Before) != XST_SUCCESS)
        return XST_FAILURE;

    After = (u8)((Before & (u8)(~ClearMask)) | SetMask);

    if (After != Before) {
        if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0, RegisterAddress, After) != XST_SUCCESS)
            return XST_FAILURE;
    }

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, RegisterAddress, &Readback) != XST_SUCCESS)
        return XST_FAILURE;

    if (Readback != After) {
        xil_printf("I2C RMW ERROR: reg 0x%04X wrote 0x%02X read 0x%02X\r\n",
                   RegisterAddress, After, Readback);
        return XST_FAILURE;
    }

    if (NewValue != NULL)
        *NewValue = Readback;

    return XST_SUCCESS;
}

static int gmax_verify_reg8(u16 Address, u8 Expected, const char *Name)
{
    u8 Value;

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, Address, &Value) != XST_SUCCESS) {
        xil_printf("  VERIFY FAIL: %s 0x%04X could not be read.\r\n", Name, Address);
        return XST_FAILURE;
    }

    xil_printf("  %s: reg 0x%04X = 0x%02X expected 0x%02X : %s\r\n",
               Name, Address, Value, Expected, (Value == Expected) ? "PASS" : "FAIL");
    return (Value == Expected) ? XST_SUCCESS : XST_FAILURE;
}

static int gmax_upload_10bit_1200_config(void)
{
    u32 i;
    u8 PwrUp = 0U;
    u8 ClkStream = 0U;
    int VerifyOk = 1;

    xil_printf("\r\n============================================================\r\n");
    xil_printf(" GMAX3412 TABLE-16 CONFIG UPLOAD\r\n");
    xil_printf(" 10-bit / 16-channel Sub-LVDS / 1.20 Gb/s / x1 PGA\r\n");
    xil_printf("============================================================\r\n");

    if (gmax_require_powered() != XST_SUCCESS)
        return XST_FAILURE;

    if (gmax_select_i2c_address(GMAX_I2C_ADDR_0) != XST_SUCCESS)
        return XST_FAILURE;

    /* A running/internal-powered sensor must be shut down before full remap. */
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PWR_UP_EN, &PwrUp) != XST_SUCCESS)
        return XST_FAILURE;
    if ((PwrUp & GMAX_PWR_UP_EN_MASK) != 0U) {
        xil_printf("REFUSED: PWR_UP_EN is already 1. Use X (internal power-down) first.\r\n");
        return XST_FAILURE;
    }

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_CLK_STREAM, &ClkStream) != XST_SUCCESS)
        return XST_FAILURE;
    if ((ClkStream & GMAX_STREAM_EN_MASK) != 0U) {
        xil_printf("  Pre-upload STREAM_EN reads 1 (0x2E00=0x%02X).\r\n", ClkStream);
        xil_printf("  Table 16 starts with 0x2E00=0x00, so this upload will explicitly clear it.\r\n");
    }

    /* No exposure request during configuration. */
    (void)gmax_ctrl_update(0U, GMAX_CTRL_TEXP1 | GMAX_CTRL_TEXP2);

    xil_printf("Writing %lu Table-16 bytes over I2C 0x10 ...\r\n",
               (unsigned long)GMAX_10B1200_CONFIG_COUNT);
    xil_printf("D_TEMP 0x3257/0x3258 are intentionally skipped (readout, not config).\r\n");

    for (i = 0U; i < GMAX_10B1200_CONFIG_COUNT; i++) {
        if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0,
                               Gmax10b1200Config[i].Address,
                               Gmax10b1200Config[i].Value) != XST_SUCCESS) {
            xil_printf("CONFIG FAIL at item %lu/%lu: reg 0x%04X value 0x%02X\r\n",
                       (unsigned long)(i + 1U),
                       (unsigned long)GMAX_10B1200_CONFIG_COUNT,
                       Gmax10b1200Config[i].Address,
                       Gmax10b1200Config[i].Value);
            GmaxConfigLoaded = 0;
            return XST_FAILURE;
        }

        if (((i + 1U) % 64U) == 0U)
            xil_printf("  ... %lu/%lu registers written\r\n",
                       (unsigned long)(i + 1U),
                       (unsigned long)GMAX_10B1200_CONFIG_COUNT);
    }

    xil_printf("  ... %lu/%lu registers written\r\n",
               (unsigned long)GMAX_10B1200_CONFIG_COUNT,
               (unsigned long)GMAX_10B1200_CONFIG_COUNT);

    xil_printf("\r\nKey-register readback:\r\n");
    if (gmax_verify_reg8(0x2E00U, 0x00U, "CLK/STREAM") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x2E02U, 0x00U, "MONO/COLR_EN") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x2EAEU, 0x12U, "PGA_GAIN x1") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x2EAFU, 0x01U, "SDO_TDIG cfg") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x3004U, 0x03U, "LVDS lanes") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x3005U, 0x00U, "CH_CLK_EN") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x3023U, 0xF8U, "PHY CTRL0") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x3024U, 0x14U, "PHY CTRL1") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x3301U, 0x00U, "PWR_UP_EN") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x3302U, 0x00U, "PWR_DOWN_EN") != XST_SUCCESS) VerifyOk = 0;
    if (gmax_verify_reg8(0x3500U, 0x10U, "Image/window") != XST_SUCCESS) VerifyOk = 0;

    if (!VerifyOk) {
        xil_printf("RESULT: FAIL - Table-16 upload completed but key readback mismatched.\r\n");
        GmaxConfigLoaded = 0;
        return XST_FAILURE;
    }

    GmaxConfigLoaded = 1;
    GmaxInternalPowered = 0;
    GmaxPhyCalibrated = 0;
    GmaxStreamEnabled = 0;

    xil_printf("RESULT: PASS - Table-16 10-bit/1.20G configuration loaded.\r\n");
    xil_printf("STREAM_EN remains 0; internal PWR_UP_EN and CH_CLK_EN remain 0.\r\n");
    return XST_SUCCESS;
}

static int gmax_phy_calibrate_sublvds(void)
{
    u8 R3023;
    u8 R3024;

    xil_printf("\r\nGMAX3412 Sub-LVDS PHY CALIBRATION\r\n");
    xil_printf("---------------------------------\r\n");

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL0, &R3023) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL1, &R3024) != XST_SUCCESS)
        return XST_FAILURE;

    xil_printf("  Initial 0x3023=0x%02X 0x3024=0x%02X\r\n", R3023, R3024);

    /* Figure 26 I2C PHY-cal sequence, preserving unrelated bits. */
    R3024 = (u8)(R3024 & (u8)(~GMAX_PHY_CTRL1_BIT5_MASK));
    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL1, R3024) != XST_SUCCESS) return XST_FAILURE;
    xil_printf("  [1] 0x3024 bit5 = 0\r\n");
    usleep(GMAX_PHY_STEP_US);

    R3023 = (u8)((R3023 & 0x0FU) | 0xF0U);
    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL0, R3023) != XST_SUCCESS) return XST_FAILURE;
    xil_printf("  [2] 0x3023[7:4] = 0xF (Sub-LVDS channels)\r\n");
    usleep(GMAX_PHY_STEP_US);

    R3023 = (u8)(R3023 | GMAX_PHY_CAL_BIT0_MASK);
    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL0, R3023) != XST_SUCCESS) return XST_FAILURE;
    xil_printf("  [3] 0x3023 bit0 = 1\r\n");
    usleep(GMAX_PHY_STEP_US);

    R3023 = (u8)(R3023 | GMAX_PHY_CAL_BITS21_MASK);
    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL0, R3023) != XST_SUCCESS) return XST_FAILURE;
    xil_printf("  [4] 0x3023[2:1] = 2'b11\r\n");
    usleep(GMAX_PHY_STEP_US);

    R3024 = (u8)(R3024 | GMAX_PHY_CTRL1_BIT5_MASK);
    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL1, R3024) != XST_SUCCESS) return XST_FAILURE;
    xil_printf("  [5] 0x3024 bit5 = 1\r\n");
    usleep(GMAX_PHY_STEP_US);

    R3023 = (u8)(R3023 & (u8)(~0x04U));
    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL0, R3023) != XST_SUCCESS) return XST_FAILURE;
    xil_printf("  [6] 0x3023 bit2 = 0\r\n");
    usleep(GMAX_PHY_STEP_US);

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL0, &R3023) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PHY_CTRL1, &R3024) != XST_SUCCESS)
        return XST_FAILURE;

    xil_printf("  Final   0x3023=0x%02X 0x3024=0x%02X\r\n", R3023, R3024);
    xil_printf("  RESULT: PHY calibration sequence completed.\r\n");
    return XST_SUCCESS;
}

static int gmax_internal_power_up_10bit(void)
{
    u8 Value;

    xil_printf("\r\n============================================================\r\n");
    xil_printf(" GMAX3412 INTERNAL POWER-UP + SUB-LVDS PHY CAL\r\n");
    xil_printf("============================================================\r\n");

    if (gmax_require_powered() != XST_SUCCESS)
        return XST_FAILURE;

    if (!GmaxConfigLoaded) {
        xil_printf("ERROR: Table-16 configuration is not marked loaded. Run option 8 first.\r\n");
        return XST_FAILURE;
    }

    if (GmaxInternalPowered || GmaxStreamEnabled) {
        xil_printf("REFUSED: internal power-up/streaming is already active. Use X first.\r\n");
        return XST_FAILURE;
    }

    /* Keep streaming disabled throughout power-up. */
    if (gmax_i2c_rmw8(GMAX_I2C_REG_CLK_STREAM,
                      GMAX_CLK_STABLE_EN_MASK,
                      GMAX_STREAM_EN_MASK,
                      &Value) != XST_SUCCESS)
        return XST_FAILURE;
    xil_printf("  CLK_STABLE_EN=1, STREAM_EN=0 -> 0x2E00=0x%02X\r\n", Value);
    xil_printf("  Waiting %u ms for internal PLL/clock stabilization ...\r\n",
               (unsigned int)(GMAX_INTERNAL_PLL_US / 1000U));
    usleep(GMAX_INTERNAL_PLL_US);

    /* Ensure a previous power-down request is not left asserted. */
    if (gmax_i2c_rmw8(GMAX_I2C_REG_PWR_DOWN_EN, 0U,
                      GMAX_PWR_DOWN_EN_MASK, &Value) != XST_SUCCESS)
        return XST_FAILURE;

    if (gmax_i2c_rmw8(GMAX_I2C_REG_PWR_UP_EN,
                      GMAX_PWR_UP_EN_MASK, 0U, &Value) != XST_SUCCESS)
        return XST_FAILURE;
    xil_printf("  PWR_UP_EN=1 -> 0x3301=0x%02X\r\n", Value);
    xil_printf("  Waiting %u ms for internal supplies ...\r\n",
               (unsigned int)(GMAX_INTERNAL_PWRUP_US / 1000U));
    usleep(GMAX_INTERNAL_PWRUP_US);
    GmaxInternalPowered = 1;

    if (gmax_i2c_rmw8(GMAX_I2C_REG_CH_CLK_EN,
                      GMAX_CH_CLK_EN_MASK, 0U, &Value) != XST_SUCCESS)
        return XST_FAILURE;
    xil_printf("  CH_CLK_EN=1 -> 0x3005=0x%02X\r\n", Value);
    usleep(GMAX_CH_CLK_SETTLE_US);

    if (gmax_phy_calibrate_sublvds() != XST_SUCCESS) {
        GmaxPhyCalibrated = 0;
        xil_printf("RESULT: FAIL - internal power is ON but PHY calibration failed.\r\n");
        xil_printf("Use X or O before retrying.\r\n");
        return XST_FAILURE;
    }

    GmaxPhyCalibrated = 1;
    GmaxStreamEnabled = 0;

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_CLK_STREAM, &Value) != XST_SUCCESS)
        return XST_FAILURE;
    if ((Value & GMAX_STREAM_EN_MASK) != 0U) {
        xil_printf("ERROR: STREAM_EN unexpectedly reads 1 after pre-stream init.\r\n");
        return XST_FAILURE;
    }

    xil_printf("\r\nRESULT: PASS - sensor internally powered and Sub-LVDS PHY calibrated.\r\n");
    xil_printf("STREAM_EN is still 0. High-speed image output has NOT been enabled.\r\n");
    return XST_SUCCESS;
}

static int gmax_complete_10bit_pre_stream_init(void)
{
    xil_printf("\r\n============================================================\r\n");
    xil_printf(" GMAX3412 COMPLETE 10-bit PRE-STREAM INITIALIZATION\r\n");
    xil_printf("============================================================\r\n");

    if (gmax_power_up_i2c() != XST_SUCCESS)
        return XST_FAILURE;
    if (gmax_upload_10bit_1200_config() != XST_SUCCESS)
        return XST_FAILURE;
    if (gmax_internal_power_up_10bit() != XST_SUCCESS)
        return XST_FAILURE;

    xil_printf("\r\nCOMPLETE PRE-STREAM INIT: PASS\r\n");
    xil_printf("Camera is powered/configured/calibrated, but STREAM_EN=0.\r\n");
    GmaxPatternRecoveryRequired = 0;
    return XST_SUCCESS;
}

static int gmax_rxdiag_select(unsigned int Lane, unsigned int Index)
{
    u32 SetMask = 0U;
    u32 ClearMask = GMAX_CTRL_RXDBG_INDEX_MASK | GMAX_CTRL_RXDBG_LANE;

    if ((Lane > 1U) || (Index > 13U))
        return XST_FAILURE;

    SetMask |= ((u32)Index << GMAX_CTRL_RXDBG_INDEX_SHIFT) &
               GMAX_CTRL_RXDBG_INDEX_MASK;
    if (Lane != 0U)
        SetMask |= GMAX_CTRL_RXDBG_LANE;

    if (gmax_ctrl_update(SetMask, ClearMask) != XST_SUCCESS)
        return XST_FAILURE;

    /* More than enough for the two-stage 120 MHz control synchronizers. */
    usleep(10U);
    return XST_SUCCESS;
}

static int gmax_rxdiag_set_freeze(int Freeze)
{
    if (Freeze)
        return gmax_ctrl_update(GMAX_CTRL_RXDBG_FREEZE, 0U);

    return gmax_ctrl_update(0U, GMAX_CTRL_RXDBG_FREEZE);
}

static int gmax_read_rx_training_registers(u16 *TrainingWord)
{
    u8 ClkStream;
    u8 OutMode;
    u8 HloOrder;
    u8 TpLow;
    u8 TpHigh;
    u16 Tp;
    int Ok = 1;

    if (TrainingWord == NULL)
        return XST_FAILURE;

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_CLK_STREAM, &ClkStream) != XST_SUCCESS)
        return XST_FAILURE;
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_OUT_MODE_SEL, &OutMode) != XST_SUCCESS)
        return XST_FAILURE;
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_HLO_ORDER, &HloOrder) != XST_SUCCESS)
        return XST_FAILURE;
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_TP_LOW, &TpLow) != XST_SUCCESS)
        return XST_FAILURE;
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_TP_HIGH, &TpHigh) != XST_SUCCESS)
        return XST_FAILURE;

    Tp = (u16)((((u16)TpHigh & 0x000FU) << 8) | (u16)TpLow);
    *TrainingWord = (u16)(Tp & 0x03FFU);

    xil_printf("\r\nSensor-side Sub-LVDS training configuration:\r\n");
    xil_printf("  0x2E00 CLK/STREAM : 0x%02X  CLK_STABLE=%u STREAM_EN=%u\r\n",
               ClkStream,
               (unsigned int)((ClkStream & GMAX_CLK_STABLE_EN_MASK) != 0U),
               (unsigned int)((ClkStream & GMAX_STREAM_EN_MASK) != 0U));
    xil_printf("  0x3000 OUT_MODE   : 0x%02X  %s\r\n",
               OutMode, ((OutMode & 0x01U) == 0U) ? "Sub-LVDS" : "MIPI");
    xil_printf("  0x3010 HLO_ORDER  : 0x%02X  %s\r\n",
               HloOrder, ((HloOrder & 0x01U) != 0U) ? "LSB first" : "MSB first");
    xil_printf("  0x3014 TP low     : 0x%02X\r\n", TpLow);
    xil_printf("  0x3015 TP high    : 0x%02X\r\n", TpHigh);
    xil_printf("  Training word     : 0x%03X\r\n", (unsigned int)*TrainingWord);

    if ((ClkStream & (GMAX_CLK_STABLE_EN_MASK | GMAX_STREAM_EN_MASK)) !=
        (GMAX_CLK_STABLE_EN_MASK | GMAX_STREAM_EN_MASK)) {
        xil_printf("  CHECK: expected CLK_STABLE_EN=1 and STREAM_EN=1 for RX diagnosis.\r\n");
        Ok = 0;
    }
    if ((OutMode & 0x01U) != 0U) {
        xil_printf("  CHECK: OUT_MODE_SEL is not Sub-LVDS.\r\n");
        Ok = 0;
    }
    if ((HloOrder & 0x01U) != 0x01U) {
        xil_printf("  CHECK: Table-16 expected HLO_ORDER=1 (LSB first).\r\n");
        Ok = 0;
    }
    if (*TrainingWord != GMAX_TRAINING_WORD_10B) {
        xil_printf("  CHECK: expected Table-16 training word 0x%03X.\r\n",
                   (unsigned int)GMAX_TRAINING_WORD_10B);
        Ok = 0;
    }

    xil_printf("  Sensor config     : %s\r\n", Ok ? "PASS" : "CHECK REQUIRED");
    return Ok ? XST_SUCCESS : XST_FAILURE;
}

static int gmax_raw_rx_diagnostic(void)
{
    u16 TrainingWord = GMAX_TRAINING_WORD_10B;
    u16 InvertedExpected;
    u32 Status;
    u32 InitialCtrl;
    unsigned int Lane;
    unsigned int Slot;
    unsigned int Word;
    unsigned int Valid;
    unsigned int RawActivity;
    unsigned int ValidCount[2] = {0U, 0U};
    unsigned int DirectMatch[2] = {0U, 0U};
    unsigned int InvertedMatch[2] = {0U, 0U};
    unsigned int LaneActivity[2] = {0U, 0U};
    int WasFrozen;
    int SensorConfigOk;

    xil_printf("\r\n============================================================\r\n");
    xil_printf(" GMAX3412 RAW SUB-LVDS RX DIAGNOSTIC - v16\r\n");
    xil_printf("============================================================\r\n");

    if (!GmaxControlReady) {
        xil_printf("ERROR: GMAX control/status AXI GPIO is not initialized.\r\n");
        return XST_FAILURE;
    }

    if (!GmaxStreamEnabled)
        xil_printf("WARNING: firmware state says STREAM_EN is not enabled; snapshot may be stale/invalid.\r\n");

    InitialCtrl = GmaxCtrlShadow;
    WasFrozen = ((InitialCtrl & GMAX_CTRL_RXDBG_FREEZE) != 0U);

    /*
     * Freeze stops new automatic retry attempts in gmax3412_rx_adapter and
     * holds the last complete training snapshot.  An in-flight attempt is
     * allowed to finish; 20 ms is comfortably longer than the observed ~5 ms
     * attempt duration in v15 logs.
     */
    if (gmax_rxdiag_set_freeze(1) != XST_SUCCESS) {
        xil_printf("ERROR: could not freeze V16 RX debug snapshot.\r\n");
        return XST_FAILURE;
    }
    usleep(20000U);

    SensorConfigOk = (gmax_read_rx_training_registers(&TrainingWord) == XST_SUCCESS);
    InvertedExpected = (u16)((~TrainingWord) & 0x03FFU);

    if (gmax_rxdiag_select(0U, 0U) != XST_SUCCESS)
        goto fail_restore;
    Status = gmax_status_read();

    xil_printf("\r\nForwarded-clock activity since RX reset:\r\n");
    xil_printf("  CLK_OUT0 / even lanes : %s\r\n",
               (Status & GMAX_STATUS_RXDBG_CLK0_MASK) ? "YES" : "NO");
    xil_printf("  CLK_OUT1 / odd lanes  : %s\r\n",
               (Status & GMAX_STATUS_RXDBG_CLK1_MASK) ? "YES" : "NO");
    xil_printf("  Status raw            : 0x%08lX\r\n", (unsigned long)Status);

    xil_printf("\r\nCandidate interpretation:\r\n");
    xil_printf("  expected TP           : 0x%03X\r\n", (unsigned int)TrainingWord);
    xil_printf("  10-bit complement     : 0x%03X\r\n", (unsigned int)InvertedExpected);
    xil_printf("  NOTE: for TP=0x165, the 10-bit complement is 0x29A, which is also\r\n");
    xil_printf("        the bit-reversed value. A 0x29A hit therefore identifies a\r\n");
    xil_printf("        polarity/bit-order candidate but cannot distinguish the two alone.\r\n");
    xil_printf("  The existing RTL actually checks 14 candidate slots (0..13); V16 logs all 14.\r\n");

    for (Lane = 0U; Lane < 2U; Lane++) {
        xil_printf("\r\nD%u candidate snapshot:\r\n", Lane);
        xil_printf("  slot   valid   word    complement   interpretation\r\n");
        xil_printf("  ----   -----   -----   ----------   --------------\r\n");

        for (Slot = 0U; Slot < 14U; Slot++) {
            if (gmax_rxdiag_select(Lane, Slot) != XST_SUCCESS)
                goto fail_restore;

            Status = gmax_status_read();
            Word = (unsigned int)((Status & GMAX_STATUS_RXDBG_WORD_MASK) >>
                                  GMAX_STATUS_RXDBG_WORD_SHIFT);
            Valid = (unsigned int)((Status & GMAX_STATUS_RXDBG_VALID_MASK) != 0U);
            RawActivity = (unsigned int)((Status & GMAX_STATUS_RXDBG_ACTIVITY_MASK) != 0U);
            if (Slot == 0U)
                LaneActivity[Lane] = RawActivity;

            if (Valid)
                ValidCount[Lane]++;

            xil_printf("   %2u      %u     0x%03X     0x%03X     ",
                       Slot, Valid, Word, (unsigned int)((~Word) & 0x03FFU));

            if (!Valid) {
                xil_printf("not captured\r\n");
            } else if (Word == (unsigned int)TrainingWord) {
                DirectMatch[Lane]++;
                xil_printf("DIRECT TP MATCH\r\n");
            } else if (Word == (unsigned int)InvertedExpected) {
                InvertedMatch[Lane]++;
                xil_printf("~TP / REVERSED-TP CANDIDATE\r\n");
            } else {
                xil_printf("no TP match\r\n");
            }
        }

        xil_printf("  Raw ISERDES activity : %s\r\n", LaneActivity[Lane] ? "YES" : "NO");
        xil_printf("  Valid candidates     : %u/14\r\n", ValidCount[Lane]);
        xil_printf("  Direct TP matches    : %u\r\n", DirectMatch[Lane]);
        xil_printf("  ~TP/reversed matches : %u\r\n", InvertedMatch[Lane]);
    }

    Status = gmax_status_read();
    xil_printf("\r\nV16 diagnosis:\r\n");
    xil_printf("  CLK_OUT0 activity    : %s\r\n",
               (Status & GMAX_STATUS_RXDBG_CLK0_MASK) ? "PASS" : "NOT OBSERVED");
    xil_printf("  CLK_OUT1 activity    : %s\r\n",
               (Status & GMAX_STATUS_RXDBG_CLK1_MASK) ? "PASS" : "NOT OBSERVED");
    xil_printf("  D0 raw activity      : %s\r\n", LaneActivity[0] ? "YES" : "NO");
    xil_printf("  D1 raw activity      : %s\r\n", LaneActivity[1] ? "YES" : "NO");

    if ((Status & GMAX_STATUS_RXDBG_CLK0_MASK) == 0U)
        xil_printf("  NEXT: investigate CLK_OUT0 path / IBUFDS / reset; clk_rxg depends on CLK_OUT0.\r\n");
    if ((Status & GMAX_STATUS_RXDBG_CLK1_MASK) == 0U)
        xil_printf("  NEXT: investigate CLK_OUT1 path; all odd data lanes use this forwarded clock.\r\n");
    if (!LaneActivity[0])
        xil_printf("  NEXT: D0 shows no pre-alignment sample activity; inspect D0 pair/cable/pin mapping.\r\n");
    if (!LaneActivity[1])
        xil_printf("  NEXT: D1 shows no pre-alignment sample activity; inspect D1 pair/cable/pin mapping.\r\n");

    for (Lane = 0U; Lane < 2U; Lane++) {
        if ((ValidCount[Lane] != 0U) && (DirectMatch[Lane] == 0U) &&
            (InvertedMatch[Lane] == 0U) && LaneActivity[Lane]) {
            xil_printf("  D%u: serial activity reaches ISERDES, but none of the 14 word-align candidates is TP.\r\n",
                       Lane);
            xil_printf("      Investigate serial bit reconstruction, IDELAY sample point and bit order.\r\n");
        }
        if (InvertedMatch[Lane] != 0U) {
            xil_printf("  D%u: 0x29A candidate seen; test lane polarity DATAIN_SWAP / bit-order handling.\r\n",
                       Lane);
        }
        if (DirectMatch[Lane] != 0U) {
            xil_printf("  D%u: expected 0x%03X is present in the captured candidates.\r\n",
                       Lane, (unsigned int)TrainingWord);
            xil_printf("      If training_result still reports FAIL, inspect alignment FSM timing/state capture.\r\n");
        }
    }

    xil_printf("  Sensor register set  : %s\r\n", SensorConfigOk ? "PASS" : "CHECK REQUIRED");
    xil_printf("============================================================\r\n");

    if (!WasFrozen)
        (void)gmax_rxdiag_set_freeze(0);

    return XST_SUCCESS;

fail_restore:
    xil_printf("ERROR: V16 RX diagnostic could not select/read a debug candidate.\r\n");
    if (!WasFrozen)
        (void)gmax_rxdiag_set_freeze(0);
    return XST_FAILURE;
}

/* BEGIN V17 TP DIAGNOSTIC: also compiled by the offline fault-injection test. */
typedef struct {
    u8 ClkStream;
    u8 TpLow;
    u8 TpHigh;
} GmaxPatternSaved;

static int gmax_pattern_write_verified(u16 Address, u8 Value)
{
    u8 Readback;

    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0, Address, Value) != XST_SUCCESS)
        return XST_FAILURE;
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, Address, &Readback) != XST_SUCCESS)
        return XST_FAILURE;
    if (Readback != Value) {
        xil_printf("TP TEST ERROR: reg 0x%04X expected 0x%02X, read 0x%02X.\r\n",
                   Address, Value, Readback);
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

static int gmax_pattern_set_stream(u8 SavedClkStream, int Enable)
{
    u8 Value = (u8)(SavedClkStream & (u8)~GMAX_STREAM_EN_MASK);

    if (Enable)
        Value |= GMAX_STREAM_EN_MASK;
    if (gmax_pattern_write_verified(GMAX_I2C_REG_CLK_STREAM, Value) != XST_SUCCESS)
        return XST_FAILURE;
    GmaxStreamEnabled = Enable != 0;
    usleep(GMAX_STREAM_SETTLE_US);
    return XST_SUCCESS;
}

static int gmax_pattern_restore(const GmaxPatternSaved *Saved)
{
    unsigned int Attempt;
    int LowOk = 0;
    int HighOk = 0;

    /* A failed transaction can have reached the sensor. Always stop and verify
     * before restoring either TP byte, with one bounded recovery retry. */
    for (Attempt = 0U; Attempt < 2U; Attempt++) {
        if (gmax_pattern_set_stream(Saved->ClkStream, 0) == XST_SUCCESS)
            break;
    }
    if (Attempt == 2U) {
        xil_printf("RESTORE FAILED: STREAM_EN=0 could not be verified.\r\n");
        xil_printf("No TP restoration writes attempted; sensor stream state is UNKNOWN.\r\n");
        return XST_FAILURE;
    }

    /* Attempt both bytes even if one fails. Do not restart with a partial TP. */
    for (Attempt = 0U; Attempt < 2U; Attempt++) {
        if (!LowOk)
            LowOk = (gmax_pattern_write_verified(GMAX_I2C_REG_TP_LOW,
                                                 Saved->TpLow) == XST_SUCCESS);
        if (!HighOk)
            HighOk = (gmax_pattern_write_verified(GMAX_I2C_REG_TP_HIGH,
                                                  Saved->TpHigh) == XST_SUCCESS);
    }
    if (!LowOk || !HighOk) {
        xil_printf("RESTORE FAILED: original TP bytes not both verified.\r\n");
        xil_printf("STREAM_EN=0 was verified; output remains stopped.\r\n");
        return XST_FAILURE;
    }

    for (Attempt = 0U; Attempt < 2U; Attempt++) {
        if (gmax_pattern_set_stream(Saved->ClkStream,
                  (Saved->ClkStream & GMAX_STREAM_EN_MASK) != 0U) == XST_SUCCESS)
            break;
    }
    if (Attempt == 2U) {
        xil_printf("RESTORE FAILED: TP restored, but original CLK/STREAM byte not verified.\r\n");
        xil_printf("Sensor stream state is UNKNOWN.\r\n");
        return XST_FAILURE;
    }
    xil_printf("RESTORED: 0x3014=0x%02X 0x3015=0x%02X 0x2E00=0x%02X.\r\n",
               Saved->TpLow, Saved->TpHigh, Saved->ClkStream);
    return XST_SUCCESS;
}

static int gmax_pattern_capture_pause(u16 Pattern)
{
    char Key;

    xil_printf("\r\nCAPTURE READY: sensor TP=0x%03X, STREAM_EN=1.\r\n", Pattern);
    xil_printf("  D0/D1 raw8 expected 0x%02X; packed word expected 0x%03X.\r\n",
               (Pattern == 0U) ? 0x00U : 0xFFU, Pattern);
    xil_printf("  In Vivado: source R:/RX_ILA/CAPTURE_RX_ILA.tcl\r\n");
    xil_printf("  Save this capture before continuing. No frame request is issued.\r\n");
    xil_printf("  Press C here (no Enter) after capture; Q/B/Esc aborts and restores: ");
    while (1) {
        Key = inbyte();
        if ((Key == '\r') || (Key == '\n'))
            continue;
        if ((Key == 'C') || (Key == 'c')) {
            xil_printf("%c\r\n", Key);
            return XST_SUCCESS;
        }
        if ((Key == 'Q') || (Key == 'q') || (Key == 'B') || (Key == 'b') ||
            ((unsigned char)Key == 0x1BU)) {
            xil_printf("ABORT\r\n");
            return XST_FAILURE;
        }
        xil_printf("\r\nUse C after capture, or Q/B/Esc to restore: ");
    }
}

static int gmax_pattern_test_interactive(void)
{
    static const u16 Patterns[2] = {0x000U, 0x3FFU};
    GmaxPatternSaved Saved;
    u8 OutMode;
    u8 HloOrder;
    u8 ChClock;
    u8 PowerUp;
    u8 PowerDown;
    u8 RegHold;
    u8 High;
    u32 SavedFreeze;
    unsigned int Index;
    char Confirm;
    int Completed = 0;
    int Aborted = 0;
    int RestoreOk;

    xil_printf("\r\nGMAX3412 CONTROLLED TP / ILA TEST - v17\r\n");
    xil_printf("----------------------------------------\r\n");
    if (GmaxPatternRecoveryRequired) {
        xil_printf("REFUSED: previous TP restoration failed. Use O, then A to recover.\r\n");
        return XST_FAILURE;
    }
    if (gmax_require_powered() != XST_SUCCESS)
        return XST_FAILURE;
    if (!GmaxConfigLoaded || !GmaxInternalPowered || !GmaxPhyCalibrated) {
        xil_printf("REFUSED: run complete 10-bit initialization A first.\r\n");
        return XST_FAILURE;
    }
    if ((GmaxCtrlShadow & (GMAX_CTRL_CCI_EN | GMAX_CTRL_XCE_SLAMODE |
                           GMAX_CTRL_TEXP1 | GMAX_CTRL_TEXP2)) != GMAX_CTRL_CCI_EN) {
        xil_printf("REFUSED: I2C 0x10 and both TEXP outputs LOW are required.\r\n");
        return XST_FAILURE;
    }
    SavedFreeze = GmaxCtrlShadow & GMAX_CTRL_RXDBG_FREEZE;

    /* All sensor state needed for restoration is saved before any sensor write. */
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_CLK_STREAM, &Saved.ClkStream) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_TP_LOW, &Saved.TpLow) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_TP_HIGH, &Saved.TpHigh) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_OUT_MODE_SEL, &OutMode) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_HLO_ORDER, &HloOrder) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_CH_CLK_EN, &ChClock) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PWR_UP_EN, &PowerUp) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_PWR_DOWN_EN, &PowerDown) != XST_SUCCESS ||
        gmax_i2c_read8_at(GMAX_I2C_ADDR_0, GMAX_I2C_REG_REG_HOLD, &RegHold) != XST_SUCCESS) {
        xil_printf("REFUSED: state could not be saved. No sensor register writes started.\r\n");
        return XST_FAILURE;
    }
    if ((Saved.ClkStream & GMAX_CLK_STABLE_EN_MASK) == 0U ||
        (ChClock & GMAX_CH_CLK_EN_MASK) == 0U ||
        (PowerUp & GMAX_PWR_UP_EN_MASK) == 0U ||
        (PowerDown & GMAX_PWR_DOWN_EN_MASK) != 0U ||
        (RegHold & GMAX_REG_HOLD_MASK) != 0U ||
        (OutMode & 0x01U) != 0U || (HloOrder & 0x01U) != 0x01U) {
        xil_printf("REFUSED: live sensor state differs from prepared Table-16 Sub-LVDS mode.\r\n");
        xil_printf("No sensor register writes started. Use O, then A to initialize.\r\n");
        return XST_FAILURE;
    }

    xil_printf("Saved: TP bytes 0x3014=0x%02X 0x3015=0x%02X; CLK/STREAM=0x%02X.\r\n",
               Saved.TpLow, Saved.TpHigh, Saved.ClkStream);
    xil_printf("This test temporarily enables high-speed output for TP=000, then TP=3FF.\r\n");
    xil_printf("The FPGA still expects 0x165: training failure with these patterns is expected.\r\n");
    xil_printf("Do not use A/S/F between captures. Keep Vivado Hardware Manager open.\r\n");
    xil_printf("Type Y to begin; any other key cancels without sensor writes: ");
    do {
        Confirm = inbyte();
    } while ((Confirm == '\r') || (Confirm == '\n'));
    xil_printf("%c\r\n", Confirm);
    if ((Confirm != 'Y') && (Confirm != 'y')) {
        xil_printf("CANCELLED: original sensor state retained.\r\n");
        return XST_FAILURE;
    }

    GmaxPatternRecoveryRequired = 1;
    if (gmax_rxdiag_set_freeze(0) != XST_SUCCESS)
        goto restore;
    for (Index = 0U; Index < 2U; Index++) {
        if (gmax_pattern_set_stream(Saved.ClkStream, 0) != XST_SUCCESS)
            goto restore;
        High = (u8)((Saved.TpHigh & 0xF0U) | ((Patterns[Index] >> 8) & 0x0FU));
        if (gmax_pattern_write_verified(GMAX_I2C_REG_TP_LOW,
                                         (u8)Patterns[Index]) != XST_SUCCESS ||
            gmax_pattern_write_verified(GMAX_I2C_REG_TP_HIGH, High) != XST_SUCCESS)
            goto restore;
        if (gmax_pattern_set_stream(Saved.ClkStream, 1) != XST_SUCCESS)
            goto restore;
        usleep(20000U);
        if (gmax_pattern_capture_pause(Patterns[Index]) != XST_SUCCESS) {
            Aborted = 1;
            goto restore;
        }
    }
    Completed = 1;

restore:
    xil_printf("\r\nRestoring original sensor state ...\r\n");
    RestoreOk = (gmax_pattern_restore(&Saved) == XST_SUCCESS);
    if (gmax_rxdiag_set_freeze(SavedFreeze != 0U) != XST_SUCCESS) {
        xil_printf("RESTORE FAILED: original RX debug-freeze state not restored.\r\n");
        RestoreOk = 0;
    }
    GmaxPatternRecoveryRequired = !RestoreOk;
    if (!RestoreOk) {
        xil_printf("RESULT: FAIL - recovery required; stream/frame/pulse tests blocked.\r\n");
        xil_printf("Use O, then A. Do not assume the saved sensor state was restored.\r\n");
        return XST_FAILURE;
    }
    xil_printf("RX debug-freeze restored to %u.\r\n", (unsigned int)(SavedFreeze != 0U));
    if (!Completed) {
        xil_printf("RESULT: %s - original state restored.\r\n", Aborted ? "ABORTED" : "FAIL");
        return XST_FAILURE;
    }
    xil_printf("RESULT: COMPLETE - both pattern capture pauses completed; original state restored.\r\n");
    xil_printf("Compare the ILA captures to evaluate the data path; this is not a receiver PASS.\r\n");
    return XST_SUCCESS;
}
/* END V17 TP DIAGNOSTIC */

static int gmax_stream_enable_interactive(void)
{
    char Confirm;
    u8 Value;

    xil_printf("\r\nGMAX3412 ENABLE HIGH-SPEED SUB-LVDS OUTPUT\r\n");
    xil_printf("------------------------------------------\r\n");

    if (GmaxPatternRecoveryRequired) {
        xil_printf("REFUSED: TP recovery required. Use O, then A before S.\r\n");
        return XST_FAILURE;
    }

    if (!GmaxInternalPowered || !GmaxPhyCalibrated) {
        xil_printf("ERROR: complete internal power-up + PHY calibration first (option 9 or A).\r\n");
        return XST_FAILURE;
    }

    xil_printf("Current receiver build uses FPGA-side TERM_100 on all 16 data pairs\r\n");
    xil_printf("and both forwarded clock pairs.\r\n");
    xil_printf("Type Y to set STREAM_EN=1; any other key aborts: ");
    Confirm = inbyte();
    xil_printf("%c\r\n", Confirm);
    if ((Confirm != 'y') && (Confirm != 'Y')) {
        xil_printf("ABORTED: STREAM_EN remains off.\r\n");
        return XST_FAILURE;
    }

    /* Ensure the V16 diagnostic hold is released before starting/retrying RX training. */
    if (gmax_rxdiag_set_freeze(0) != XST_SUCCESS) {
        xil_printf("ERROR: could not release V16 RX diagnostic hold.\r\n");
        return XST_FAILURE;
    }

    if (gmax_i2c_rmw8(GMAX_I2C_REG_CLK_STREAM,
                      GMAX_STREAM_EN_MASK, 0U, &Value) != XST_SUCCESS)
        return XST_FAILURE;
    usleep(GMAX_STREAM_SETTLE_US);

    GmaxStreamEnabled = ((Value & GMAX_STREAM_EN_MASK) != 0U);
    xil_printf("0x2E00 readback = 0x%02X (STREAM_EN=%u, CLK_STABLE_EN=%u)\r\n",
               Value,
               (unsigned int)((Value & GMAX_STREAM_EN_MASK) != 0U),
               (unsigned int)((Value & GMAX_CLK_STABLE_EN_MASK) != 0U));

    if (!GmaxStreamEnabled) {
        xil_printf("RESULT: FAIL - STREAM_EN did not latch.\r\n");
        return XST_FAILURE;
    }

    xil_printf("STREAM_EN=1. Sensor training pattern should now be continuously active.\r\n");

    {
        u16 TpReadback = 0U;
        if (gmax_read_rx_training_registers(&TpReadback) != XST_SUCCESS)
            xil_printf("WARNING: sensor-side training register readback needs attention.\r\n");
    }

    if (gmax_wait_for_training(GMAX_TRAINING_TIMEOUT_US) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - STREAM_EN is ON, but PL receiver training did not lock all 16 lanes.\r\n");
        xil_printf("Launching V16 raw receiver diagnostic automatically ...\r\n");
        (void)gmax_raw_rx_diagnostic();
        xil_printf("Use D to repeat the raw RX snapshot; use T for current training status; X stops/powers down.\r\n");
        return XST_FAILURE;
    }

    xil_printf("RESULT: PASS - STREAM_EN=1 and PL receiver training_result=0xFFFF.\r\n");
    xil_printf("All 16 Sub-LVDS data lanes are word-aligned. Do not request a frame until this PASS.\r\n");
    return XST_SUCCESS;
}

static int gmax_request_one_frame(void)
{
    xil_printf("\r\nGMAX3412 ONE-FRAME TEXP1 REQUEST\r\n");
    xil_printf("--------------------------------\r\n");

    if (GmaxPatternRecoveryRequired) {
        xil_printf("REFUSED: TP recovery required. Use O, then A before frame tests.\r\n");
        return XST_FAILURE;
    }

    if (!GmaxStreamEnabled) {
        xil_printf("ERROR: STREAM_EN is not enabled. Use S first.\r\n");
        return XST_FAILURE;
    }

    (void)gmax_ctrl_update(0U, GMAX_CTRL_TEXP1 | GMAX_CTRL_TEXP2);
    usleep(10U);
    xil_printf("TEXP1 -> HIGH for %u us, then LOW.\r\n", (unsigned int)GMAX_FRAME_PULSE_US);
    if (gmax_ctrl_update(GMAX_CTRL_TEXP1, 0U) != XST_SUCCESS)
        return XST_FAILURE;
    usleep(GMAX_FRAME_PULSE_US);
    if (gmax_ctrl_update(0U, GMAX_CTRL_TEXP1) != XST_SUCCESS)
        return XST_FAILURE;

    xil_printf("RESULT: one TEXP1 request issued. Observe CLK_OUT0/1 and data lanes.\r\n");
    return XST_SUCCESS;
}

static int gmax_internal_power_down(void)
{
    u8 Value;
    int Result = XST_SUCCESS;

    xil_printf("\r\nGMAX3412 INTERNAL POWER-DOWN\r\n");
    xil_printf("----------------------------\r\n");

    if (gmax_require_powered() != XST_SUCCESS)
        return XST_FAILURE;

    (void)gmax_ctrl_update(0U, GMAX_CTRL_TEXP1 | GMAX_CTRL_TEXP2);

    /* Driving flow: stop capture first, then power down internal supplies. */
    if (gmax_i2c_rmw8(GMAX_I2C_REG_CLK_STREAM, 0U,
                      GMAX_STREAM_EN_MASK, &Value) != XST_SUCCESS) {
        Result = XST_FAILURE;
    } else {
        xil_printf("  STREAM_EN=0 -> 0x2E00=0x%02X\r\n", Value);
        usleep(GMAX_STREAM_SETTLE_US);
    }
    GmaxStreamEnabled = 0;

    if (gmax_i2c_rmw8(GMAX_I2C_REG_PWR_UP_EN, 0U,
                      GMAX_PWR_UP_EN_MASK, &Value) != XST_SUCCESS) {
        Result = XST_FAILURE;
    } else {
        xil_printf("  PWR_UP_EN=0 -> 0x3301=0x%02X\r\n", Value);
    }

    if (gmax_i2c_rmw8(GMAX_I2C_REG_PWR_DOWN_EN,
                      GMAX_PWR_DOWN_EN_MASK, 0U, &Value) != XST_SUCCESS) {
        Result = XST_FAILURE;
    } else {
        xil_printf("  PWR_DOWN_EN=1 -> 0x3302=0x%02X\r\n", Value);
        usleep(GMAX_PHY_STEP_US);
    }

    GmaxInternalPowered = 0;
    GmaxPhyCalibrated = 0;
    GmaxConfigLoaded = 0; /* force a fresh Table-16 upload before next start */

    xil_printf("RESULT: %s - external FH_Sen4K rails/40 MHz remain ON.\r\n",
               (Result == XST_SUCCESS) ? "PASS" : "CHECK REQUIRED");
    return Result;
}

static int gmax_basic_i2c_probe(void)
{
    u8 Reg00 = 0U;

    xil_printf("\r\n============================================================\r\n");
    xil_printf(" GMAX_A BASIC READ-ONLY I2C PROBE\r\n");
    xil_printf("============================================================\r\n");
    xil_printf("GPIO base : 0x%08lX\r\n", (unsigned long)FH_GMAX_GPIO_BASEADDR);
    xil_printf("I2C base  : 0x%08lX\r\n", (unsigned long)FH_GMAX_IIC_BASEADDR);
    xil_printf("I2C addr  : 0x%02X (SLAMODE=0)\r\n", GMAX_I2C_ADDR_0);
    xil_printf("Operation : READ ONLY; no GMAX register writes\r\n");

    if (!GmaxControlReady) {
        xil_printf("Initializing GMAX PL control to SAFE/OFF ...\r\n");
        if (gmax_hw_init_safe() != XST_SUCCESS) {
            xil_printf("RESULT: FAIL - GMAX PL control initialization\r\n");
            return XST_FAILURE;
        }
    }

    if (!GmaxPowered || !GmaxResetReleased || !GmaxClockEnabled) {
        xil_printf("Applying safe external FH_Sen4K power/reset/40-MHz sequence ...\r\n");
        if (gmax_power_up_i2c() != XST_SUCCESS) {
            xil_printf("RESULT: FAIL - external camera power/control sequence\r\n");
            return XST_FAILURE;
        }
    }

#if FH_GMAX_IIC_AVAILABLE
    if (!GmaxIicReady) {
        if (gmax_iic_driver_init() != XST_SUCCESS) {
            xil_printf("RESULT: FAIL - AXI IIC driver/config initialization\r\n");
            return XST_FAILURE;
        }
    }
#endif

    xil_printf("Reading register 0x%04X ...\r\n", GMAX_I2C_REG_CLK_STREAM);
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_CLK_STREAM,
                          &Reg00) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - no valid GMAX3412 I2C response\r\n");
        return XST_FAILURE;
    }

    xil_printf("Register 0x%04X = 0x%02X\r\n",
               GMAX_I2C_REG_CLK_STREAM, Reg00);
    xil_printf("  CLK_STABLE_EN = %u\r\n",
               (unsigned int)((Reg00 & GMAX_CLK_STABLE_EN_MASK) != 0U));
    xil_printf("  STREAM_EN     = %u\r\n",
               (unsigned int)((Reg00 & GMAX_STREAM_EN_MASK) != 0U));
    xil_printf("RESULT: PASS - GMAX_A ACKed and returned one register byte over I2C\r\n");
    xil_printf("Sensor left externally powered, reset released, 40 MHz enabled,\r\n");
    xil_printf("I2C selected; internal PWR_UP_EN/CH_CLK_EN/STREAM_EN were not changed.\r\n");
    return XST_SUCCESS;
}

static int gmax_test_i2c(void)
{
    u8 Reg00;
    u8 RegAf;
    u8 Verify;

    xil_printf("\r\nGMAX3412 I2C COMMUNICATION TEST\r\n");
    xil_printf("-------------------------------\r\n");
    xil_printf("Slave address  : 0x%02X (SLAMODE=0)\r\n", GMAX_I2C_ADDR_0);

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_CLK_STREAM,
                          &Reg00) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - no valid read from I2C register 0x%04X.\r\n",
                   GMAX_I2C_REG_CLK_STREAM);
        return XST_FAILURE;
    }

    xil_printf("Read 0x%04X = 0x%02X (CLK_STABLE_EN/STREAM_EN register)\r\n",
               GMAX_I2C_REG_CLK_STREAM, Reg00);

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_SDO_TDIG_SEL,
                          &RegAf) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - no valid read from I2C register 0x%04X.\r\n",
                   GMAX_I2C_REG_SDO_TDIG_SEL);
        return XST_FAILURE;
    }

    xil_printf("Read 0x%04X = 0x%02X (SDO_TDIG_SEL bit1=%u)\r\n",
               GMAX_I2C_REG_SDO_TDIG_SEL,
               RegAf,
               (unsigned int)((RegAf & GMAX_SDO_TDIG_SEL_MASK) != 0U));

    /* Prove the I2C write path without changing any register value. */
    xil_printf("Writing the SAME value 0x%02X back to 0x%04X for safe write-path test ...\r\n",
               RegAf, GMAX_I2C_REG_SDO_TDIG_SEL);
    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0,
                           GMAX_I2C_REG_SDO_TDIG_SEL,
                           RegAf) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - I2C same-value write failed.\r\n");
        return XST_FAILURE;
    }

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_SDO_TDIG_SEL,
                          &Verify) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - I2C readback failed.\r\n");
        return XST_FAILURE;
    }

    xil_printf("Readback       = 0x%02X\r\n", Verify);
    if (Verify != RegAf) {
        xil_printf("RESULT: FAIL - I2C same-value write/readback mismatch.\r\n");
        return XST_FAILURE;
    }

    xil_printf("RESULT: PASS - I2C read + safe same-value write/readback.\r\n");
    return XST_SUCCESS;
}

static int gmax_test_i2c_address_select(void)
{
    u8 Value0 = 0U;
    u8 Value1 = 0U;
    int Ok0;
    int Ok1;

    xil_printf("\r\nGMAX3412 OPTIONAL SLAMODE ADDRESS TEST\r\n");
    xil_printf("-------------------------------------\r\n");

    Ok0 = (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                             GMAX_I2C_REG_CLK_STREAM,
                             &Value0) == XST_SUCCESS);
    xil_printf("SLAMODE=0 / 0x10 : %s", Ok0 ? "ACK/read PASS" : "FAIL");
    if (Ok0)
        xil_printf(" (0x2E00=0x%02X)", Value0);
    xil_printf("\r\n");

    Ok1 = (gmax_i2c_read8_at(GMAX_I2C_ADDR_1,
                             GMAX_I2C_REG_CLK_STREAM,
                             &Value1) == XST_SUCCESS);
    xil_printf("SLAMODE=1 / 0x1A : %s", Ok1 ? "ACK/read PASS" : "FAIL");
    if (Ok1)
        xil_printf(" (0x2E00=0x%02X)", Value1);
    xil_printf("\r\n");

    /* Always return to the normal bench address 0x10. */
    (void)gmax_select_i2c_address(GMAX_I2C_ADDR_0);

    if (Ok0 && Ok1) {
        xil_printf("RESULT: PASS - both documented SLAMODE addresses responded.\r\n");
        return XST_SUCCESS;
    }

    xil_printf("RESULT: CHECK REQUIRED - normal bring-up only requires 0x10.\r\n");
    return XST_FAILURE;
}

static void gmax_spi_delay(void)
{
    usleep(GMAX_SPI_HALF_PERIOD_US);
}

static void gmax_spi_set_sck(int High)
{
    if (High)
        (void)gmax_ctrl_update(GMAX_CTRL_SPI_SCK, 0U);
    else
        (void)gmax_ctrl_update(0U, GMAX_CTRL_SPI_SCK);
}

static void gmax_spi_set_sdi(int High)
{
    if (High)
        (void)gmax_ctrl_update(GMAX_CTRL_SPI_SDI, 0U);
    else
        (void)gmax_ctrl_update(0U, GMAX_CTRL_SPI_SDI);
}

static void gmax_spi_clock_tx_bit(unsigned int Bit)
{
    /*
     * Match the Gpixel reference SPI PHY: SCK idles HIGH.  Drive SCK low,
     * present SDI, then raise SCK; GMAX3412 samples SDI on that rising edge.
     * The helper leaves SCK HIGH ready for the next bit.
     */
    gmax_spi_set_sck(0);
    gmax_spi_set_sdi(Bit != 0U);
    gmax_spi_delay();
    gmax_spi_set_sck(1);
    gmax_spi_delay();
}

static int gmax_prepare_spi(void)
{
    u8 SdoSel;
    u8 Verify;
    u8 NewValue;
    u32 SpiIdle;

    if (gmax_require_powered() != XST_SUCCESS)
        return XST_FAILURE;

    /* Keep the validated SPI diagnostic out of an active imaging state. */
    if (GmaxInternalPowered || GmaxStreamEnabled) {
        xil_printf("SPI PREP REFUSED: internal sensor power/streaming is active.\r\n");
        xil_printf("Use X first, then run the low-speed SPI diagnostic.\r\n");
        return XST_FAILURE;
    }

    /* SDO_TDIG pin must be SDO (bit1=0) before changing CCI_EN to SPI. */
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_SDO_TDIG_SEL,
                          &SdoSel) != XST_SUCCESS) {
        xil_printf("SPI PREP FAIL: cannot read SDO_TDIG_SEL over I2C.\r\n");
        return XST_FAILURE;
    }

    NewValue = (u8)(SdoSel & (u8)~GMAX_SDO_TDIG_SEL_MASK);
    if (NewValue != SdoSel) {
        xil_printf("SPI PREP: clearing SDO_TDIG_SEL bit1 via I2C: 0x%02X -> 0x%02X\r\n",
                   SdoSel, NewValue);
        if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0,
                               GMAX_I2C_REG_SDO_TDIG_SEL,
                               NewValue) != XST_SUCCESS)
            return XST_FAILURE;
    }

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_SDO_TDIG_SEL,
                          &Verify) != XST_SUCCESS)
        return XST_FAILURE;

    if ((Verify & GMAX_SDO_TDIG_SEL_MASK) != 0U) {
        xil_printf("SPI PREP FAIL: SDO_TDIG_SEL is still 1 (TDIG).\r\n");
        return XST_FAILURE;
    }

    /*
     * Change CCI_EN=0 and XCE=1 in one AXI GPIO write; SCK uses the reference-PHY HIGH idle level and SDI is low.
     * When CCI_EN=0 the dual-purpose pin becomes active-low XCE.
     */
    SpiIdle = GmaxCtrlShadow;
    SpiIdle &= ~(GMAX_CTRL_CCI_EN | GMAX_CTRL_SPI_SDI);
    SpiIdle |= (GMAX_CTRL_XCE_SLAMODE | GMAX_CTRL_SPI_SCK);

    if (gmax_ctrl_write(SpiIdle) != XST_SUCCESS)
        return XST_FAILURE;

    usleep(20U);
    return XST_SUCCESS;
}

static void gmax_restore_i2c(void)
{
    u32 I2cState = GmaxCtrlShadow;

    I2cState |= GMAX_CTRL_CCI_EN;
    I2cState &= ~(GMAX_CTRL_XCE_SLAMODE | GMAX_CTRL_SPI_SCK | GMAX_CTRL_SPI_SDI);
    (void)gmax_ctrl_write(I2cState);
    usleep(20U);
}

static int gmax_spi_read8(u16 RegisterAddress, u8 *Value)
{
    u16 AddressWord;
    int Bit;
    u8 Data = 0U;

    if (Value == NULL)
        return XST_FAILURE;

    /* A15=1 selects SPI read. */
    AddressWord = (u16)((RegisterAddress & 0x7FFFU) | 0x8000U);

    /* Idle state follows the Gpixel reference PHY: XCE high, SCK high. */
    (void)gmax_ctrl_update(GMAX_CTRL_XCE_SLAMODE | GMAX_CTRL_SPI_SCK,
                           GMAX_CTRL_SPI_SDI);
    gmax_spi_delay();

    /* Assert XCE while SCK stays high, then wait before first address clock. */
    (void)gmax_ctrl_update(0U, GMAX_CTRL_XCE_SLAMODE);
    gmax_spi_delay();

    for (Bit = 15; Bit >= 0; Bit--)
        gmax_spi_clock_tx_bit((unsigned int)((AddressWord >> Bit) & 1U));

    /* During read data phase SDI is don't-care; hold it low. */
    gmax_spi_set_sdi(0);

    /*
     * GMAX3412 changes SDO on each falling edge.  Therefore clock LOW to
     * launch D7..D0, wait, return HIGH, then sample while the bit is stable.
     */
    for (Bit = 7; Bit >= 0; Bit--) {
        gmax_spi_set_sck(0);
        gmax_spi_delay();
        gmax_spi_set_sck(1);
        gmax_spi_delay();

        if ((gmax_status_read() & GMAX_STATUS_SDO_TDIG) != 0U)
            Data |= (u8)(1U << Bit);
    }

    /* Keep XCE low for extra margin after the final rising edge. */
    gmax_spi_delay();
    gmax_spi_delay();
    (void)gmax_ctrl_update(GMAX_CTRL_XCE_SLAMODE | GMAX_CTRL_SPI_SCK,
                           GMAX_CTRL_SPI_SDI);
    gmax_spi_delay();

    *Value = Data;
    return XST_SUCCESS;
}

static int gmax_spi_write8(u16 RegisterAddress, u8 Value)
{
    u16 AddressWord = (u16)(RegisterAddress & 0x7FFFU); /* A15=0 => write */
    int Bit;

    (void)gmax_ctrl_update(GMAX_CTRL_XCE_SLAMODE | GMAX_CTRL_SPI_SCK,
                           GMAX_CTRL_SPI_SDI);
    gmax_spi_delay();

    (void)gmax_ctrl_update(0U, GMAX_CTRL_XCE_SLAMODE);
    gmax_spi_delay();

    for (Bit = 15; Bit >= 0; Bit--)
        gmax_spi_clock_tx_bit((unsigned int)((AddressWord >> Bit) & 1U));

    for (Bit = 7; Bit >= 0; Bit--)
        gmax_spi_clock_tx_bit((unsigned int)((Value >> Bit) & 1U));

    gmax_spi_delay();
    gmax_spi_delay();
    (void)gmax_ctrl_update(GMAX_CTRL_XCE_SLAMODE | GMAX_CTRL_SPI_SCK,
                           GMAX_CTRL_SPI_SDI);
    gmax_spi_delay();

    return XST_SUCCESS;
}

static int gmax_test_spi(void)
{
    u8 Reg00;
    u8 RegAf;
    u8 Verify;

    xil_printf("\r\nGMAX3412 SPI COMMUNICATION TEST\r\n");
    xil_printf("-------------------------------\r\n");

    if (gmax_prepare_spi() != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - SPI preparation failed.\r\n");
        gmax_restore_i2c();
        return XST_FAILURE;
    }

    if (gmax_spi_read8(GMAX_SPI_REG_CLK_STREAM, &Reg00) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - SPI read 0x%04X failed.\r\n", GMAX_SPI_REG_CLK_STREAM);
        gmax_restore_i2c();
        return XST_FAILURE;
    }
    xil_printf("SPI read 0x%04X = 0x%02X\r\n", GMAX_SPI_REG_CLK_STREAM, Reg00);

    if (gmax_spi_read8(GMAX_SPI_REG_SDO_TDIG_SEL, &RegAf) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - SPI read 0x%04X failed.\r\n", GMAX_SPI_REG_SDO_TDIG_SEL);
        gmax_restore_i2c();
        return XST_FAILURE;
    }
    xil_printf("SPI read 0x%04X = 0x%02X\r\n", GMAX_SPI_REG_SDO_TDIG_SEL, RegAf);

    /* Prove SPI write path without changing the register value. */
    xil_printf("SPI writing SAME value 0x%02X back to 0x%04X ...\r\n",
               RegAf, GMAX_SPI_REG_SDO_TDIG_SEL);
    (void)gmax_spi_write8(GMAX_SPI_REG_SDO_TDIG_SEL, RegAf);

    if (gmax_spi_read8(GMAX_SPI_REG_SDO_TDIG_SEL, &Verify) != XST_SUCCESS) {
        xil_printf("RESULT: FAIL - SPI readback failed.\r\n");
        gmax_restore_i2c();
        return XST_FAILURE;
    }

    xil_printf("SPI readback   = 0x%02X\r\n", Verify);
    gmax_restore_i2c();

    if (Verify != RegAf) {
        xil_printf("RESULT: FAIL - SPI same-value write/readback mismatch.\r\n");
        return XST_FAILURE;
    }

    xil_printf("RESULT: PASS - SPI read + safe same-value write/readback.\r\n");
    xil_printf("Interface restored to I2C / SLAMODE=0 (0x10).\r\n");
    return XST_SUCCESS;
}

static int gmax_complete_serial_test(void)
{
    u8 I2cReg00;
    u8 SpiReg00;
    u8 I2cRegAf;
    u8 SpiRegAf;
    u8 Verify;
    int Result = XST_FAILURE;

    xil_printf("\r\n============================================================\r\n");
    xil_printf(" FH_Sen4K / GMAX3412-A COMPLETE CONTROL + SERIAL TEST\r\n");
    xil_printf("============================================================\r\n");

    if (gmax_power_up_i2c() != XST_SUCCESS) {
        xil_printf("STOP: safe external power/reset/clock sequence failed.\r\n");
        return XST_FAILURE;
    }

    xil_printf("\r\n[COMM 1] I2C read baseline\r\n");
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_CLK_STREAM,
                          &I2cReg00) != XST_SUCCESS)
        goto done;

    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_SDO_TDIG_SEL,
                          &I2cRegAf) != XST_SUCCESS)
        goto done;

    xil_printf("  I2C 0x2E00 = 0x%02X\r\n", I2cReg00);
    xil_printf("  I2C 0x2EAF = 0x%02X\r\n", I2cRegAf);

    xil_printf("\r\n[COMM 2] I2C safe write/readback on 0x2EAF\r\n");
    if (gmax_i2c_write8_at(GMAX_I2C_ADDR_0,
                           GMAX_I2C_REG_SDO_TDIG_SEL,
                           I2cRegAf) != XST_SUCCESS)
        goto done;
    if (gmax_i2c_read8_at(GMAX_I2C_ADDR_0,
                          GMAX_I2C_REG_SDO_TDIG_SEL,
                          &Verify) != XST_SUCCESS)
        goto done;
    if (Verify != I2cRegAf) {
        xil_printf("  FAIL: I2C readback 0x%02X != 0x%02X\r\n", Verify, I2cRegAf);
        goto done;
    }
    xil_printf("  PASS: I2C write/readback matched.\r\n");

    xil_printf("\r\n[COMM 3] Select SDO and switch CCI to SPI\r\n");
    if (gmax_prepare_spi() != XST_SUCCESS)
        goto done;

    xil_printf("\r\n[COMM 4] SPI reads\r\n");
    if (gmax_spi_read8(GMAX_SPI_REG_CLK_STREAM, &SpiReg00) != XST_SUCCESS)
        goto restore_i2c;
    if (gmax_spi_read8(GMAX_SPI_REG_SDO_TDIG_SEL, &SpiRegAf) != XST_SUCCESS)
        goto restore_i2c;

    xil_printf("  SPI 0x0000 = 0x%02X\r\n", SpiReg00);
    xil_printf("  SPI 0x00AF = 0x%02X\r\n", SpiRegAf);

    xil_printf("\r\n[COMM 5] SPI safe same-value write/readback on 0x00AF\r\n");
    (void)gmax_spi_write8(GMAX_SPI_REG_SDO_TDIG_SEL, SpiRegAf);
    if (gmax_spi_read8(GMAX_SPI_REG_SDO_TDIG_SEL, &Verify) != XST_SUCCESS)
        goto restore_i2c;
    if (Verify != SpiRegAf) {
        xil_printf("  FAIL: SPI readback 0x%02X != 0x%02X\r\n", Verify, SpiRegAf);
        goto restore_i2c;
    }
    xil_printf("  PASS: SPI write/readback matched.\r\n");

    xil_printf("\r\n[COMM 6] Cross-interface comparison\r\n");
    xil_printf("  CLK/STREAM register: I2C=0x%02X SPI=0x%02X -> %s\r\n",
               I2cReg00, SpiReg00, (I2cReg00 == SpiReg00) ? "MATCH" : "MISMATCH");

    if (I2cReg00 != SpiReg00) {
        xil_printf("  FAIL: same physical register does not match across I2C/SPI.\r\n");
        goto restore_i2c;
    }

    Result = XST_SUCCESS;

restore_i2c:
    gmax_restore_i2c();

done:
    xil_printf("\r\n------------------------------------------------------------\r\n");
    xil_printf(" FH_Sen4K COMPLETE TEST: %s\r\n", Result == XST_SUCCESS ? "PASS" : "FAIL");
    xil_printf(" Camera left powered, reset released, 40 MHz enabled, I2C 0x10 selected.\r\n");
    xil_printf(" No low-speed test write to PWR_UP_EN/CH_CLK_EN/STREAM_EN was made.\r\n");
    xil_printf(" (The pre-existing CLK/STREAM register value is reported, not assumed.)\r\n");
    xil_printf(" Use submenu O to return FH_Sen4K to SAFE/OFF.\r\n");
    xil_printf("------------------------------------------------------------\r\n");
    return Result;
}

static void gmax_test_texp_outputs(void)
{
    xil_printf("\r\nGMAX_A TEXP OUTPUT PULSE TEST\r\n");
    xil_printf("-----------------------------\r\n");

    if (GmaxPatternRecoveryRequired) {
        xil_printf("REFUSED: TP recovery required. Use O, then A before pulse tests.\r\n");
        return;
    }

    if (!GmaxControlReady) {
        xil_printf("ERROR: GMAX control GPIO is not initialized.\r\n");
        return;
    }

    if (GmaxStreamEnabled) {
        xil_printf("REFUSED: STREAM_EN is active; use F for a deliberate frame request.\r\n");
        return;
    }

    xil_printf("TEXP1: 100 us HIGH pulse (scope on GMX_A_TEXP1)\r\n");
    (void)gmax_ctrl_update(GMAX_CTRL_TEXP1, 0U);
    usleep(100U);
    (void)gmax_ctrl_update(0U, GMAX_CTRL_TEXP1);
    usleep(1000U);

    xil_printf("TEXP2: 100 us HIGH pulse (scope on GMX_A_TEXP2)\r\n");
    (void)gmax_ctrl_update(GMAX_CTRL_TEXP2, 0U);
    usleep(100U);
    (void)gmax_ctrl_update(0U, GMAX_CTRL_TEXP2);

    xil_printf("Pulse test complete.\r\n");
}

static void show_gmax_menu(void)
{
    xil_printf("\r\n");
    xil_printf("============================================================\r\n");
    xil_printf(" FH_Sen4K / GMAX3412-A DIAGNOSTICS - v17 (V16.3 RX)\r\n");
    xil_printf("============================================================\r\n");
    xil_printf(" 1 - Show control / AXI / GMAX state\r\n");
    xil_printf(" 2 - Safe external power-up (I2C 0x10, reset, 40 MHz)\r\n");
    xil_printf(" 3 - I2C read + same-value write/readback test\r\n");
    xil_printf(" 4 - Optional SLAMODE address test (0x10 and 0x1A)\r\n");
    xil_printf(" 5 - SPI read + same-value write/readback test\r\n");
    xil_printf(" 6 - COMPLETE low-speed control + I2C + SPI test\r\n");
    xil_printf(" 7 - Raw TEXP1/TEXP2 100 us GPIO pulse test (stream OFF only)\r\n");
    xil_printf(" 8 - Upload Gpixel Table-16 10-bit/1.20G Sub-LVDS config\r\n");
    xil_printf(" 9 - GMAX internal power-up + Sub-LVDS PHY calibration\r\n");
    xil_printf(" I - BASIC read-only I2C probe (auto safe power-up if needed)\r\n");
    xil_printf(" A - COMPLETE 10-bit pre-stream init (2 + 8 + 9)\r\n");
    xil_printf(" S - Enable STREAM_EN=1 + wait for 16-lane RX training\r\n");
    xil_printf(" T - Read PL receiver training status (training_result/done)\r\n");
    xil_printf(" D - V16 raw RX diagnostic: clocks + D0/D1 candidate words\r\n");
    xil_printf(" P - Controlled TP=000/3FF test with ILA pauses + restoration\r\n");
    xil_printf(" F - Request one frame with a 100 us TEXP1 pulse\r\n");
    xil_printf(" X - Stop stream + GMAX internal power-down; keep board ON\r\n");
    xil_printf(" O - Graceful GMAX + FH_Sen4K external power-down\r\n");
    xil_printf(" H - Show this submenu\r\n");
    xil_printf(" B - Back to main menu\r\n");
    xil_printf("------------------------------------------------------------\r\n");
    xil_printf("Safety: Table-16 upload and option 9 leave STREAM_EN=0.\r\n");
    xil_printf("S enables streaming; P temporarily streams diagnostic patterns, both after Y.\r\n");
}

static void gmax_menu(void)
{
    char Command;

    if (!GmaxControlReady)
        (void)gmax_hw_init_safe();

    show_gmax_menu();

    while (1) {
        Command = inbyte();

        if (((unsigned char)Command != 0x1BU) &&
            (Command != '\r') && (Command != '\n'))
            xil_printf("\r\n[GMAX] > %c\r\n", Command);

        switch (Command) {
        case '1':
            gmax_show_status();
            break;
        case '2':
            (void)gmax_power_up_i2c();
            break;
        case '3':
            (void)gmax_test_i2c();
            break;
        case '4':
            (void)gmax_test_i2c_address_select();
            break;
        case '5':
            (void)gmax_test_spi();
            break;
        case '6':
            (void)gmax_complete_serial_test();
            break;
        case '7':
            gmax_test_texp_outputs();
            break;
        case '8':
            (void)gmax_upload_10bit_1200_config();
            break;
        case '9':
            (void)gmax_internal_power_up_10bit();
            break;
        case 'i':
        case 'I':
            (void)gmax_basic_i2c_probe();
            break;
        case 'a':
        case 'A':
            (void)gmax_complete_10bit_pre_stream_init();
            break;
        case 's':
        case 'S':
            (void)gmax_stream_enable_interactive();
            break;
        case 't':
        case 'T':
            gmax_show_training_status();
            break;
        case 'd':
        case 'D':
            (void)gmax_raw_rx_diagnostic();
            break;
        case 'p':
        case 'P':
            (void)gmax_pattern_test_interactive();
            break;
        case 'f':
        case 'F':
            (void)gmax_request_one_frame();
            break;
        case 'x':
        case 'X':
            (void)gmax_internal_power_down();
            break;
        case 'o':
        case 'O':
            gmax_power_down();
            break;
        case 'h':
        case 'H':
        case '?':
            show_gmax_menu();
            break;
        case 'b':
        case 'B':
        case 0x1B:
            xil_printf("Returning to main menu.\r\n");
            show_menu();
            return;
        case '\r':
        case '\n':
            break;
        default:
            xil_printf("Unknown GMAX command. Press H for submenu.\r\n");
            break;
        }
    }
}

/* ------------------------------------------------------------------------- */
/* Differential reference-clock diagnostics                                 */
/* ------------------------------------------------------------------------- */

static const char *clock_result_string(FhClockResult Result)
{
    switch (Result) {
    case FH_CLOCK_PASS:
        return "PASS";
    case FH_CLOCK_FAIL:
        return "FAIL";
    case FH_CLOCK_CONFIG_ERROR:
        return "CONFIG ERROR";
    case FH_CLOCK_NOT_INITIALIZED:
        return "NOT INITIALIZED";
    default:
        return "UNAVAILABLE";
    }
}

static const char *ps_gtr_refclk_code_string(u32 Code)
{
    switch (Code & FH_GTR_PLL_REF_SEL_MASK) {
    case 0x00U: return "5 MHz";
    case 0x01U: return "9.6 MHz";
    case 0x02U: return "10 MHz";
    case 0x03U: return "12 MHz";
    case 0x04U: return "13 MHz";
    case 0x05U: return "19.2 MHz";
    case 0x06U: return "20 MHz";
    case 0x07U: return "24 MHz";
    case 0x08U: return "26 MHz";
    case 0x09U: return "27 MHz";
    case 0x0AU: return "38.4 MHz";
    case 0x0BU: return "40 MHz";
    case 0x0CU: return "52 MHz";
    case 0x0DU: return "100 MHz";
    case 0x0EU: return "108 MHz";
    case 0x0FU: return "125 MHz";
    case 0x10U: return "135 MHz";
    case 0x11U: return "150 MHz";
    default:    return "RESERVED/UNKNOWN";
    }
}


static const char *ps_gtr_protocol_string(u32 Code)
{
    switch (Code & 0x7U) {
    case 0U: return "PowerDown";
    case 1U: return "PCIe";
    case 2U: return "SATA";
    case 3U: return "USB";
    case 4U: return "DisplayPort";
    case 5U: return "SGMII";
    default: return "Reserved";
    }
}

static const char *sata_det_string(u32 Det)
{
    switch (Det & 0xFU) {
    case 0U: return "No device / no PHY communication";
    case 1U: return "Device detected, PHY communication not established";
    case 3U: return "Device detected, PHY communication established";
    case 4U: return "PHY offline";
    default: return "Reserved/unknown";
    }
}

static const char *sata_spd_string(u32 Spd)
{
    switch (Spd & 0xFU) {
    case 0U: return "Not negotiated";
    case 1U: return "Gen1 1.5 Gb/s";
    case 2U: return "Gen2 3.0 Gb/s";
    case 3U: return "Gen3 6.0 Gb/s";
    default: return "Reserved/unknown";
    }
}

static const char *sata_ipm_string(u32 Ipm)
{
    switch (Ipm & 0xFU) {
    case 0U: return "No interface state reported";
    case 1U: return "Active";
    case 2U: return "Partial";
    case 6U: return "Slumber";
    case 8U: return "DevSleep";
    default: return "Reserved/unknown";
    }
}

/*
 * Synopsys DWC3 SuperSpeed link-state coding used by the USB3 controller.
 * The same numeric values are used by the standard xHCI Port Link State
 * field for the normal SuperSpeed states.
 */
static const char *usb3_link_state_string(u32 State)
{
    switch (State & 0xFU) {
    case 0U:  return "U0 (operational)";
    case 1U:  return "U1";
    case 2U:  return "U2";
    case 3U:  return "U3";
    case 4U:  return "SS.Disabled";
    case 5U:  return "RxDetect";
    case 6U:  return "SS.Inactive";
    case 7U:  return "Polling";
    case 8U:  return "Recovery";
    case 9U:  return "Hot Reset";
    case 10U: return "Compliance";
    case 11U: return "Loopback";
    case 14U: return "Reset";
    case 15U: return "Resume";
    default:  return "Reserved/unknown";
    }
}

static const char *usb3_clk_state_string(u32 State)
{
    switch (State & 0x7U) {
    case 0U: return "CLK_NORM (PCLK running)";
    case 1U: return "CLK_TO_P3";
    case 2U: return "CLK_WAIT1";
    case 3U: return "CLK_P3 (PCLK stopped in P3)";
    case 4U: return "CLK_TO_P0";
    case 5U: return "CLK_WAIT2";
    default: return "Reserved/unknown";
    }
}

static int usb3_link_is_functional(u32 LinkState)
{
    /*
     * U0 is fully operational. U1/U2/U3 are valid SuperSpeed low-power
     * states reached only after a link has been established.
     */
    return ((LinkState & 0xFU) <= 3U);
}

static void report_sata_link_state(void)
{
    u32 Ssts = Xil_In32(FH_SATA_P0_SSTS);
    u32 Det = Ssts & FH_SATA_SSTS_DET_MASK;
    u32 Spd = (Ssts & FH_SATA_SSTS_SPD_MASK) >> FH_SATA_SSTS_SPD_SHIFT;
    u32 Ipm = (Ssts & FH_SATA_SSTS_IPM_MASK) >> FH_SATA_SSTS_IPM_SHIFT;

    xil_printf("  SATA PxSSTS : 0x%08lX\r\n", (unsigned long)Ssts);
    xil_printf("  SATA DET    : %lu - %s\r\n",
               (unsigned long)Det, sata_det_string(Det));
    xil_printf("  SATA SPD    : %lu - %s\r\n",
               (unsigned long)Spd, sata_spd_string(Spd));
    xil_printf("  SATA IPM    : %lu - %s\r\n",
               (unsigned long)Ipm, sata_ipm_string(Ipm));

    if (Det == 3U)
        xil_printf("  SATA link   : ESTABLISHED (extra functional evidence)\r\n");
    else
        xil_printf("  SATA link   : NOT ESTABLISHED (does not fail REFCLK test)\r\n");
}

static int report_usb3_debug_state(void)
{
    u32 Gdbg = Xil_In32(FH_USB3_GDBGLTSSM);
    u32 LinkState =
        (Gdbg & FH_USB3_LINK_STATE_MASK) >> FH_USB3_LINK_STATE_SHIFT;
    u32 ClkState =
        (Gdbg & FH_USB3_CLK_STATE_MASK) >> FH_USB3_CLK_STATE_SHIFT;
    u32 PowerDown =
        (Gdbg & FH_USB3_POWERDOWN_MASK) >> FH_USB3_POWERDOWN_SHIFT;
    int RxElecIdle = ((Gdbg & FH_USB3_RXELECIDLE_MASK) != 0U);
    int RxTermination = ((Gdbg & FH_USB3_RXTERM_MASK) != 0U);
    int RegisterValid = ((Gdbg != 0U) && (Gdbg != 0xFFFFFFFFU));
    int Functional = RegisterValid && usb3_link_is_functional(LinkState);

    xil_printf("  USB3 GDB    : 0x%08lX\r\n", (unsigned long)Gdbg);
    xil_printf("  GDB valid   : %s\r\n", RegisterValid ? "YES" : "NO");
    xil_printf("  USB3 link   : %s\r\n", usb3_link_state_string(LinkState));
    xil_printf("  PIPE clock  : %s\r\n", usb3_clk_state_string(ClkState));
    xil_printf("  PowerDown   : P%lu\r\n", (unsigned long)PowerDown);
    xil_printf("  RxElecIdle  : %s\r\n", RxElecIdle ? "YES" : "NO");
    xil_printf("  RxTerm      : %s\r\n", RxTermination ? "ON" : "OFF");

    if (Functional) {
        xil_printf("  Link proof  : YES - SuperSpeed link reached a valid U-state\r\n");
        if (LinkState == 0U)
            xil_printf("                U0 is direct functional evidence of USB3 operation.\r\n");
    } else {
        xil_printf("  Link proof  : NO - no established SuperSpeed U-state now\r\n");
        xil_printf("                (this can be normal with no USB3 device attached).\r\n");
    }

    return Functional;
}

/*
 * USB3 lane-1 reference-clock/configuration check.
 *
 * Do not use L1_PLL_STATUS_READ_1 as a USB PASS/FAIL criterion.  During
 * validated IBERT operation FH_Carrier reached USB0 Linked (U0) with
 * FD4063E4 still equal to 0x00000001.  The register is retained below only
 * as raw diagnostic information.
 */
static FhClockResult test_usb3_refclk_config(void)
{
    u32 StatusValue = Xil_In32(FH_GTR_L1_PLL_STATUS_READ_1);
    u32 RefFreqValue = Xil_In32(FH_GTR_PLL_REF_SEL1);
    u32 RefFreqCode = RefFreqValue & FH_GTR_PLL_REF_SEL_MASK;
    u32 RefMuxValue = Xil_In32(FH_GTR_L1_REF_CLK_SEL);
    u32 IcmCfg0 = Xil_In32(FH_GTR_ICM_CFG0);
    u32 ProtocolCode =
        (IcmCfg0 & FH_GTR_L1_PROTOCOL_MASK) >> FH_GTR_L1_PROTOCOL_SHIFT;
    int RefFreqOk = (RefFreqCode == FH_GTR_USB3_REF_FREQ_CODE);
    int RefMuxOk =
        ((RefMuxValue & FH_GTR_L1_REF_CLK_SEL_MASK) ==
         (FH_GTR_L1_REF_CLK_SEL_EXPECT & FH_GTR_L1_REF_CLK_SEL_MASK));
    int ProtocolOk = (ProtocolCode == FH_GTR_L1_PROTOCOL_EXPECT);
    int ResetDefaults =
        (ProtocolCode == 0U) &&
        (RefFreqCode == FH_GTR_L1_RESET_REF_FREQ_CODE) &&
        ((RefMuxValue & FH_GTR_L1_REF_CLK_SEL_MASK) ==
         (FH_GTR_REF_CLK_SEL_RESET & FH_GTR_L1_REF_CLK_SEL_MASK));
    FhClockResult Result;

    xil_printf("\r\nUSB3_CLK100\r\n");
    xil_printf("  Path        : PS-GTR Bank 505 REFCLK1 / lane 1\r\n");
    xil_printf("  Expected    : 100 MHz\r\n");
    xil_printf("  Protocol    : %s (code %lu)\r\n",
               ps_gtr_protocol_string(ProtocolCode),
               (unsigned long)ProtocolCode);
    xil_printf("  Prot expect : %s (code %lu)\r\n",
               ps_gtr_protocol_string(FH_GTR_L1_PROTOCOL_EXPECT),
               (unsigned long)FH_GTR_L1_PROTOCOL_EXPECT);
    xil_printf("  Prot config : %s\r\n", ProtocolOk ? "PASS" : "FAIL");

    xil_printf("  Ref config  : %s (code 0x%02lX)\r\n",
               ps_gtr_refclk_code_string(RefFreqCode),
               (unsigned long)RefFreqCode);
    xil_printf("  Ref expected: %s (code 0x%02lX)\r\n",
               ps_gtr_refclk_code_string(FH_GTR_USB3_REF_FREQ_CODE),
               (unsigned long)FH_GTR_USB3_REF_FREQ_CODE);
    xil_printf("  Freq config : %s%s\r\n",
               RefFreqOk ? "PASS" : "FAIL",
               ResetDefaults ? " (RESET DEFAULT)" : "");

    xil_printf("  Ref mux     : 0x%08lX (mask 0x%08lX)\r\n",
               (unsigned long)RefMuxValue,
               (unsigned long)FH_GTR_L1_REF_CLK_SEL_MASK);
    xil_printf("  Mux expected: 0x%08lX\r\n",
               (unsigned long)(FH_GTR_L1_REF_CLK_SEL_EXPECT &
                               FH_GTR_L1_REF_CLK_SEL_MASK));
    xil_printf("  Mux config  : %s%s\r\n",
               RefMuxOk ? "PASS" : "FAIL",
               ResetDefaults ? " (RESET DEFAULT)" : "");

    xil_printf("  PLL raw     : 0x%08lX (diagnostic only)\r\n",
               (unsigned long)StatusValue);
    xil_printf("  PLL policy  : NOT used for USB3 PASS/FAIL\r\n");

    if (ResetDefaults) {
        Result = FH_CLOCK_NOT_INITIALIZED;
        xil_printf("  Diagnosis   : PS-GTR lane1 static configuration is still at\r\n");
        xil_printf("                reset defaults; FSBL/psu_init did not configure USB3.\r\n");
    } else if (!ProtocolOk || !RefFreqOk || !RefMuxOk) {
        Result = FH_CLOCK_CONFIG_ERROR;
        xil_printf("  Diagnosis   : USB3 protocol/REFCLK PCW/XSA configuration does not\r\n");
        xil_printf("                match FH_Carrier (USB lane1, REFCLK1, 100 MHz).\r\n");
    } else {
        Result = FH_CLOCK_PASS;
    }

    xil_printf("  Result      : %s\r\n", clock_result_string(Result));
    return Result;
}

/*
 * Apply the same minimal DWC3 GCTL update used by AMD's IBERT FSBL helper,
 * then watch GDBGLTSSM for a real SuperSpeed U-state.  This does not perform
 * xHCI enumeration; PORTSC_30 therefore remains unsuitable as the criterion
 * in this bring-up flow.
 */
static int usb3_prepare_and_check_link(void)
{
    u32 GctlBefore;
    u32 GctlWritten;
    u32 GctlReadback;
    u32 Gdbg = 0U;
    u32 LinkState = 0xFFFFFFFFU;
    u32 ElapsedUs;
    int SawU0 = 0;
    int SawFunctionalUState = 0;

    GctlBefore = Xil_In32(FH_USB3_GCTL);
    GctlWritten = GctlBefore & FH_USB3_GCTL_U0_LTSSM_MASK;
    Xil_Out32(FH_USB3_GCTL, GctlWritten);
    GctlReadback = Xil_In32(FH_USB3_GCTL);

    xil_printf("  USB3 GCTL before : 0x%08lX\r\n",
               (unsigned long)GctlBefore);
    xil_printf("  USB3 GCTL after  : 0x%08lX\r\n",
               (unsigned long)GctlReadback);
    xil_printf("  GCTL[13:12]      : 0x%lX (IBERT helper expects 0x1)\r\n",
               (unsigned long)((GctlReadback & FH_USB3_GCTL_LTSSM_FIELD_MASK) >> 12U));

    if ((GctlReadback & FH_USB3_GCTL_LTSSM_FIELD_MASK) !=
        FH_USB3_GCTL_LTSSM_EXPECT) {
        xil_printf("  WARNING     : minimal IBERT GCTL update did not produce GCTL[13:12]=01.\r\n");
    }

    /*
     * Poll for up to two seconds. U0 is the strongest direct observation,
     * but U1/U2/U3 also prove that a SuperSpeed link was established.
     */
    for (ElapsedUs = 0U;
         ElapsedUs <= FH_USB3_LINK_POLL_TIMEOUT_US;
         ElapsedUs += FH_USB3_LINK_POLL_INTERVAL_US) {
        Gdbg = Xil_In32(FH_USB3_GDBGLTSSM);

        if ((Gdbg != 0U) && (Gdbg != 0xFFFFFFFFU)) {
            LinkState =
                (Gdbg & FH_USB3_LINK_STATE_MASK) >> FH_USB3_LINK_STATE_SHIFT;

            if (LinkState == 0U) {
                SawU0 = 1;
                SawFunctionalUState = 1;
                break;
            }

            if (usb3_link_is_functional(LinkState))
                SawFunctionalUState = 1;
        }

        if ((ElapsedUs + FH_USB3_LINK_POLL_INTERVAL_US) >
            FH_USB3_LINK_POLL_TIMEOUT_US)
            break;

        usleep(FH_USB3_LINK_POLL_INTERVAL_US);
    }

    xil_printf("  Link wait   : %lu ms\r\n",
               (unsigned long)(ElapsedUs / 1000U));
    xil_printf("  U0 observed : %s\r\n", SawU0 ? "YES" : "NO");

    /* Print the final live PIPE/LTSSM state. */
    if (report_usb3_debug_state())
        SawFunctionalUState = 1;

    if (SawU0) {
        xil_printf("  USB verdict : PASS - U0 observed directly\r\n");
    } else if (SawFunctionalUState) {
        xil_printf("  USB verdict : PASS - established SuperSpeed low-power U-state\r\n");
    } else {
        xil_printf("  USB verdict : NO LINK - static REFCLK configuration is valid,\r\n");
        xil_printf("                but no established SuperSpeed U-state was observed.\r\n");
        xil_printf("                This is expected if no USB3 link partner is attached.\r\n");
    }

    return SawFunctionalUState;
}

static FhClockResult test_ps_gtr_pll(UINTPTR StatusAddress,
                                     UINTPTR RefFreqAddress,
                                     u32 ExpectedRefFreqCode,
                                     u32 ResetRefFreqCode,
                                     UINTPTR RefMuxAddress,
                                     u32 RefMuxMask,
                                     u32 ExpectedRefMux,
                                     u32 ProtocolMask,
                                     u32 ProtocolShift,
                                     u32 ExpectedProtocol,
                                     const char *ClockName,
                                     const char *Path,
                                     const char *Expected)
{
    u32 StatusValue;
    u32 RefFreqValue;
    u32 RefFreqCode;
    u32 RefMuxValue;
    u32 IcmCfg0;
    u32 ProtocolCode;
    int RefFreqOk;
    int RefMuxOk;
    int ProtocolOk;
    int ResetDefaults;
    int Started;
    int Locked;
    int CoarseDone;
    FhClockResult Result;

    StatusValue = Xil_In32(StatusAddress);
    RefFreqValue = Xil_In32(RefFreqAddress);
    RefFreqCode = RefFreqValue & FH_GTR_PLL_REF_SEL_MASK;
    RefMuxValue = Xil_In32(RefMuxAddress);
    IcmCfg0 = Xil_In32(FH_GTR_ICM_CFG0);
    ProtocolCode = (IcmCfg0 & ProtocolMask) >> ProtocolShift;

    RefFreqOk = (RefFreqCode ==
                 (ExpectedRefFreqCode & FH_GTR_PLL_REF_SEL_MASK));
    RefMuxOk = ((RefMuxValue & RefMuxMask) ==
                (ExpectedRefMux & RefMuxMask));
    ProtocolOk = (ProtocolCode == ExpectedProtocol);

    /*
     * A lane is considered "not initialized" only if the frequency code,
     * reference-clock mux and PLL status are ALL still at their reset values.
     * This prevents reset defaults from being misreported as a PCW error.
     */
    ResetDefaults =
        (RefFreqCode == (ResetRefFreqCode & FH_GTR_PLL_REF_SEL_MASK)) &&
        ((RefMuxValue & RefMuxMask) ==
         (FH_GTR_REF_CLK_SEL_RESET & RefMuxMask)) &&
        (StatusValue == FH_GTR_PLL_STATUS_RESET);

    Started    = ((StatusValue & FH_GTR_PLL_START_MASK) != 0U);
    Locked     = ((StatusValue & FH_GTR_PLL_LOCK_MASK) != 0U);
    CoarseDone = ((StatusValue & FH_GTR_PLL_COARSE_DONE_MASK) != 0U);

    xil_printf("\r\n%s\r\n", ClockName);
    xil_printf("  Path        : %s\r\n", Path);
    xil_printf("  Expected    : %s\r\n", Expected);

    xil_printf("  Protocol    : %s (code %lu)\r\n",
               ps_gtr_protocol_string(ProtocolCode),
               (unsigned long)ProtocolCode);
    xil_printf("  Prot expect : %s (code %lu)\r\n",
               ps_gtr_protocol_string(ExpectedProtocol),
               (unsigned long)ExpectedProtocol);
    xil_printf("  Prot config : %s\r\n", ProtocolOk ? "PASS" : "FAIL");

    xil_printf("  Ref config  : %s (code 0x%02lX)\r\n",
               ps_gtr_refclk_code_string(RefFreqCode),
               (unsigned long)RefFreqCode);
    xil_printf("  Ref expected: %s (code 0x%02lX)\r\n",
               ps_gtr_refclk_code_string(ExpectedRefFreqCode),
               (unsigned long)(ExpectedRefFreqCode &
                               FH_GTR_PLL_REF_SEL_MASK));
    xil_printf("  Freq config : %s%s\r\n",
               RefFreqOk ? "PASS" : "FAIL",
               ResetDefaults ? " (RESET DEFAULT)" : "");

    xil_printf("  Ref mux     : 0x%08lX (mask 0x%08lX)\r\n",
               (unsigned long)RefMuxValue,
               (unsigned long)RefMuxMask);
    xil_printf("  Mux expected: 0x%08lX\r\n",
               (unsigned long)(ExpectedRefMux & RefMuxMask));
    xil_printf("  Mux config  : %s%s\r\n",
               RefMuxOk ? "PASS" : "FAIL",
               ResetDefaults ? " (RESET DEFAULT)" : "");

    xil_printf("  PLL status  : 0x%08lX%s\r\n",
               (unsigned long)StatusValue,
               ResetDefaults ? " (RESET DEFAULT)" : "");
    xil_printf("  PLL started : %s\r\n", Started ? "YES" : "NO");
    xil_printf("  Coarse done : %s\r\n", CoarseDone ? "YES" : "NO");
    xil_printf("  PLL lock    : %s\r\n", Locked ? "LOCKED" : "UNLOCKED");

    /*
     * Classification priority:
     *   1) Exact reset defaults -> NOT INITIALIZED.
     *   2) Non-reset but wrong frequency/mux -> CONFIG ERROR.
     *   3) Correct configuration but no start -> NOT INITIALIZED.
     *   4) Correct configuration and lock/coarse done -> PASS.
     *   5) Correct configuration but no lock -> FAIL.
     */
    if (ResetDefaults) {
        Result = FH_CLOCK_NOT_INITIALIZED;
        xil_printf("  Diagnosis   : PS-GTR lane is still at reset defaults.\r\n");
        xil_printf("                FSBL/psu_init has not configured this lane.\r\n");
    } else if (!ProtocolOk || !RefFreqOk || !RefMuxOk) {
        Result = FH_CLOCK_CONFIG_ERROR;
        xil_printf("  Diagnosis   : PS-GTR protocol/PCW/XSA clock configuration does not\r\n");
        xil_printf("                match the FH_Carrier hardware requirement.\r\n");
    } else if (!Started) {
        Result = FH_CLOCK_NOT_INITIALIZED;
        xil_printf("  Diagnosis   : Frequency/mux configuration is correct, but\r\n");
        xil_printf("                the PS-GTR PLL has not completed initialization.\r\n");
    } else if (Locked && CoarseDone) {
        Result = FH_CLOCK_PASS;
    } else {
        Result = FH_CLOCK_FAIL;
        xil_printf("  Diagnosis   : Configuration matches the board, but PLL\r\n");
        xil_printf("                failed to lock. Check the physical REFCLK.\r\n");
    }

    xil_printf("  Result      : %s\r\n", clock_result_string(Result));

    return Result;
}

static FhClockResult test_pcie_refclk_frequency(void)
{
#if FH_CLKMON_AVAILABLE
    u32 PcapStatus;
    u32 Count;
    u32 Status;
    u32 Frequency_kHz;
    int Valid;
    int Present;
    int InRange;
    FhClockResult Result;

    /*
     * Never access the PL AXI GPIO unless the CSU reports that PL
     * configuration reached DONE and End-Of-Startup.  An AXI read to an
     * unconfigured/reset PL slave can otherwise stall the A53 indefinitely.
     */
    PcapStatus = Xil_In32(FH_CSU_PCAP_STATUS);

    xil_printf("\r\nM2_PCIE_REFCLK_SOM\r\n");
    xil_printf("  Path        : GTH Bank 223 MGTREFCLK0\r\n");
    xil_printf("  Expected    : 100.000 MHz\r\n");
    xil_printf("  PCAP status : 0x%08lX\r\n",
               (unsigned long)PcapStatus);
    xil_printf("  PL INIT     : %s\r\n",
               (PcapStatus & FH_PCAP_PL_INIT_MASK) ? "YES" : "NO");
    xil_printf("  PL DONE     : %s\r\n",
               (PcapStatus & FH_PCAP_PL_DONE_MASK) ? "YES" : "NO");
    xil_printf("  PL EOS      : %s\r\n",
               (PcapStatus & FH_PCAP_PL_EOS_MASK) ? "YES" : "NO");
    xil_printf("  PL CFG_RST_B: %s\r\n",
               (PcapStatus & FH_PCAP_PL_CFG_RESET_B_MASK) ? "RELEASED" : "ASSERTED");

    if ((PcapStatus & FH_PCAP_PL_READY_MASK) != FH_PCAP_PL_READY_MASK) {
        xil_printf("  AXI GPIO    : SKIPPED\r\n");
        xil_printf("  Reason      : PL configuration is not DONE+EOS.\r\n");
        xil_printf("  Safety      : no access made to 0x%08lX.\r\n",
                   (unsigned long)FH_CLKMON_BASEADDR);
        xil_printf("  Result      : UNAVAILABLE\r\n");
        return FH_CLOCK_UNAVAILABLE;
    }

    /* The HDL continuously updates the completed 10 ms sample; no delay is required here. */

    Count = Xil_In32(FH_CLKMON_BASEADDR + FH_CLKMON_GPIO_CH1_DATA);
    Status = Xil_In32(FH_CLKMON_BASEADDR + FH_CLKMON_GPIO_CH2_DATA);

    Valid   = ((Status & FH_CLKMON_STATUS_VALID) != 0U);
    Present = ((Status & FH_CLKMON_STATUS_PRESENT) != 0U);
    InRange = ((Status & FH_CLKMON_STATUS_IN_RANGE) != 0U);

    /*
     * The HDL counts REFCLK/2 edges for 10 ms:
     *   Count = (Fref / 2) * 0.010
     *   Fref[Hz] = Count * 200
     *   Fref[kHz] = Count / 5
     *
     * Round to nearest kHz.
     */
    Frequency_kHz = (Count + 2U) / 5U;

    xil_printf("  AXI GPIO    : 0x%08lX\r\n",
               (unsigned long)FH_CLKMON_BASEADDR);
    xil_printf("  Raw count   : %lu edges / 10 ms (ODIV2)\r\n",
               (unsigned long)Count);
    xil_printf("  Measured    : %lu.%03lu MHz\r\n",
               (unsigned long)(Frequency_kHz / 1000U),
               (unsigned long)(Frequency_kHz % 1000U));
    xil_printf("  HDL valid   : %s\r\n", Valid ? "YES" : "NO");
    xil_printf("  Clock seen  : %s\r\n", Present ? "YES" : "NO");
    xil_printf("  +/-1%% range : %s\r\n", InRange ? "YES" : "NO");

    if (!Valid) {
        Result = FH_CLOCK_UNAVAILABLE;
    } else if (!Present) {
        Result = FH_CLOCK_FAIL;
    } else if ((Frequency_kHz >= FH_PCIE_MIN_KHZ) &&
               (Frequency_kHz <= FH_PCIE_MAX_KHZ) &&
               InRange) {
        Result = FH_CLOCK_PASS;
    } else {
        Result = FH_CLOCK_FAIL;
    }

    xil_printf("  Result      : %s\r\n", clock_result_string(Result));
    return Result;
#else
    xil_printf("\r\nM2_PCIE_REFCLK_SOM\r\n");
    xil_printf("  Expected    : 100.000 MHz\r\n");
    xil_printf("  Result      : UNAVAILABLE\r\n");
    xil_printf("  Reason      : XPAR_AXI_GPIO_CLKMON_BASEADDR was not generated.\r\n");
    xil_printf("                Add the supplied monitor + dual AXI GPIO, export\r\n");
    xil_printf("                a new XSA, and rebuild the Vitis platform/BSP.\r\n");
    return FH_CLOCK_UNAVAILABLE;
#endif
}

static void test_differential_clocks(void)
{
    FhClockResult SataResult;
    FhClockResult UsbResult;
    FhClockResult PcieResult;
    int UsbFunctional = 0;

    xil_printf("\r\n");
    xil_printf("============================================================\r\n");
    xil_printf(" COMPLETE REFERENCE CLOCK DIAGNOSTICS\r\n");
    xil_printf("============================================================\r\n");

    SataResult = test_ps_gtr_pll(
        FH_GTR_L0_PLL_STATUS_READ_1,
        FH_GTR_PLL_REF_SEL0,
        FH_GTR_SATA_REF_FREQ_CODE,
        FH_GTR_L0_RESET_REF_FREQ_CODE,
        FH_GTR_L0_REF_CLK_SEL,
        FH_GTR_L0_REF_CLK_SEL_MASK,
        FH_GTR_L0_REF_CLK_SEL_EXPECT,
        FH_GTR_L0_PROTOCOL_MASK,
        FH_GTR_L0_PROTOCOL_SHIFT,
        FH_GTR_L0_PROTOCOL_EXPECT,
        "M2_SATA_REFCLK_150M",
        "PS-GTR Bank 505 REFCLK0 / lane 0",
        "150 MHz");

    UsbResult = test_usb3_refclk_config();

    /*
     * IMPORTANT:
     * SATA peripheral registers are accessed only after the lane-0 PLL test
     * passes. USB3 GCTL/GDBGLTSSM are accessed only after lane-1 protocol,
     * REFCLK frequency and REFCLK mux match the validated FH_Carrier setup.
     * This avoids touching peripheral space while its PS configuration is
     * still at reset/default values.
     */
    xil_printf("\r\nSATA FUNCTIONAL STATE\r\n");
    if (SataResult == FH_CLOCK_PASS) {
        report_sata_link_state();
    } else {
        xil_printf("  Status      : SKIPPED\r\n");
        if (SataResult == FH_CLOCK_NOT_INITIALIZED) {
            xil_printf("  Reason      : PS-GTR lane0 is not initialized.\r\n");
        } else if (SataResult == FH_CLOCK_CONFIG_ERROR) {
            xil_printf("  Reason      : PS-GTR lane0 configuration is invalid.\r\n");
        } else if (SataResult == FH_CLOCK_FAIL) {
            xil_printf("  Reason      : PS-GTR lane0 PLL has not passed lock/coarse checks.\r\n");
        } else {
            xil_printf("  Reason      : SATA clock diagnostic is unavailable.\r\n");
        }
        xil_printf("  Safety      : SATA PxSSTS was NOT read.\r\n");
    }

    xil_printf("\r\nUSB3 FUNCTIONAL/PIPE STATE\r\n");
    if (UsbResult == FH_CLOCK_PASS) {
        UsbFunctional = usb3_prepare_and_check_link();
    } else {
        xil_printf("  Status      : SKIPPED\r\n");
        if (UsbResult == FH_CLOCK_NOT_INITIALIZED) {
            xil_printf("  Reason      : PS-GTR lane1 static USB3 configuration is not initialized.\r\n");
        } else if (UsbResult == FH_CLOCK_CONFIG_ERROR) {
            xil_printf("  Reason      : PS-GTR lane1 USB3/REFCLK configuration is invalid.\r\n");
        } else {
            xil_printf("  Reason      : USB3 clock diagnostic is unavailable.\r\n");
        }
        xil_printf("  Safety      : USB3 GCTL/GDBGLTSSM were NOT accessed.\r\n");
    }

    /*
     * PCIe monitor is independent PL logic and must always be evaluated,
     * even when SATA/USB3 diagnostics are skipped.
     */
    PcieResult = test_pcie_refclk_frequency();

    /* Preserve the results for the consolidated start-up summary. */
    LastSataClockResult = SataResult;
    LastUsbClockResult = UsbResult;
    LastPcieClockResult = PcieResult;
    LastUsbFunctional = UsbFunctional;

    xil_printf("\r\n");
    xil_printf("------------------------------------------------------------\r\n");
    xil_printf(" CLOCK TEST SUMMARY\r\n");
    xil_printf("------------------------------------------------------------\r\n");
    xil_printf(" SATA 150 MHz : %s\r\n", clock_result_string(SataResult));
    xil_printf(" USB3 100 MHz : %s\r\n", clock_result_string(UsbResult));
    if (UsbResult == FH_CLOCK_PASS)
        xil_printf(" USB3 SS link : %s\r\n", UsbFunctional ? "PASS" : "NOT ESTABLISHED");
    else
        xil_printf(" USB3 SS link : SKIPPED\r\n");
    xil_printf(" PCIe 100 MHz : %s\r\n", clock_result_string(PcieResult));

    if ((SataResult == FH_CLOCK_PASS) &&
        (UsbResult == FH_CLOCK_PASS) &&
        (PcieResult == FH_CLOCK_PASS)) {
        xil_printf(" Overall      : PASS\r\n");
    } else if ((SataResult == FH_CLOCK_CONFIG_ERROR) ||
               (UsbResult == FH_CLOCK_CONFIG_ERROR)) {
        xil_printf(" Overall      : CONFIG ERROR\r\n");
        xil_printf(" Correct the Vivado PS-GTR reference-clock settings, export\r\n");
        xil_printf(" a new XSA, and rebuild the Vitis platform before judging\r\n");
        xil_printf(" the physical oscillator.\r\n");
    } else if ((SataResult == FH_CLOCK_NOT_INITIALIZED) ||
               (UsbResult == FH_CLOCK_NOT_INITIALIZED) ||
               (PcieResult == FH_CLOCK_UNAVAILABLE)) {
        xil_printf(" Overall      : CHECK REQUIRED\r\n");
        xil_printf(" NOT INITIALIZED means the PS-GTR lane is still at reset\r\n");
        xil_printf(" defaults or its initialization has not completed.\r\n");
        xil_printf(" It is not proof of a bad oscillator.\r\n");
    } else {
        xil_printf(" Overall      : FAIL\r\n");
    }

    xil_printf("------------------------------------------------------------\r\n");
    xil_printf("NOTE: SATA/USB3 diagnostics verify protocol assignment and PCW/XSA\r\n");
    xil_printf("REFCLK configuration. SATA additionally uses its lane-0 PLL status.\r\n");
    xil_printf("USB3 does NOT use FD4063E4 for PASS/FAIL; it applies the AMD IBERT\r\n");
    xil_printf("GCTL helper update and checks GDBGLTSSM for a real SuperSpeed U-state.\r\n");
    xil_printf("USB3 PORTSC is intentionally not used because this flow does not\r\n");
    xil_printf("perform xHCI enumeration. PCIe AXI GPIO is accessed only when PL\r\n");
    xil_printf("PCAP reports DONE+EOS. SATA/USB3 are not precision frequency counters.\r\n");
    xil_printf("PCIe frequency is measured directly by the PL counter. Firmware cannot measure\r\n");
    xil_printf("differential amplitude, common-mode voltage, duty cycle, rise/fall\r\n");
    xil_printf("time or jitter.\r\n");
}

static void run_startup_diagnostics(void)
{
    u8 EepromByte = 0U;

    GpioReady = 0;
    IicReady = 0;
    PacReady = 0;
    PacResponding = 0;
    I2c1ResetWasAsserted = 0;
    I2c1ResetReleasedByDiagnostic = 0;
    GmaxControlReady = 0;
    GmaxIicReady = 0;
    GmaxPowered = 0;
    GmaxResetReleased = 0;
    GmaxClockEnabled = 0;
    GmaxConfigLoaded = 0;
    GmaxInternalPowered = 0;
    GmaxPhyCalibrated = 0;
    GmaxStreamEnabled = 0;
    GmaxCtrlShadow = GMAX_CTRL_SAFE_I2C;

    xil_printf("\r\n");
    xil_printf("============================================================\r\n");
    xil_printf(" START-UP DIAGNOSTICS - incremental, stop point is meaningful\r\n");
    xil_printf("============================================================\r\n");
    xil_printf("If UART output stops after an 'About to...' or 'MMIO READ ...'\r\n");
    xil_printf("line, that next access/call is the exact hang point.\r\n");

    diag_step(1U, "Initialize PS GPIO and read FH_Carrier power-good inputs");
    if (init_gpio() == XST_SUCCESS) {
        GpioReady = 1;
        xil_printf("      PASS: PS GPIO initialized.\r\n");
        test_power_good();
    } else {
        GpioReady = 0;
        xil_printf("      FAIL: PS GPIO initialization failed.\r\n");
    }

    diag_step(5U, "Initialize FH_Sen4K/GMAX_A PL control to SAFE/OFF state");
    if (gmax_hw_init_safe() == XST_SUCCESS)
        xil_printf("      PASS: FH_Sen4K control initialized SAFE/OFF.\r\n");
    else
        xil_printf("      WARNING: FH_Sen4K control unavailable; main diagnostics continue.\r\n");

    diag_step(10U, "Initialize known-good PS I2C0/MIO path (EEPROM baseline)");
    xil_printf("      About to initialize PS I2C0.\r\n");

    if (init_i2c0() == XST_SUCCESS) {
        IicReady = 1;
        xil_printf("      PASS: PS I2C0 initialized.\r\n");
        xil_printf("      Reading EEPROM byte 0x00 to prove XIicPs + PS I2C0 baseline ...\r\n");

        if (eeprom_read(0x00U, &EepromByte, 1U) == XST_SUCCESS)
            xil_printf("      PASS: EEPROM responded; byte[0x00] = 0x%02X\r\n", EepromByte);
        else
            xil_printf("      WARNING: I2C0 initialized but EEPROM baseline read failed.\r\n");
    } else {
        IicReady = 0;
        xil_printf("      FAIL: PS I2C0 initialization failed.\r\n");
    }

    if (init_pac1944_i2c1() == XST_SUCCESS) {
        PacReady = 1;
        xil_printf("\r\n      RESULT: PS I2C1 controller/EMIO initialization diagnostics PASS.\r\n");
    } else {
        PacReady = 0;
        xil_printf("\r\n      RESULT: PS I2C1 controller/EMIO initialization diagnostics FAIL.\r\n");
    }

    if (PacReady) {
        if (diagnostic_pac1944_pid_transaction() == XST_SUCCESS)
            PacResponding = 1;
        else
            PacResponding = 0;
    } else {
        PacResponding = 0;
        xil_printf("\r\n[D90] PAC1944 transaction skipped because I2C1 is not ready.\r\n");
    }

    /*
     * v8: Clock analysis is part of every complete start-up diagnostic run.
     * This executes the same validated routine exposed by interactive option 7.
     */
    diag_step(100U, "Run complete SATA/USB3/PCIe reference-clock diagnostics");
    test_differential_clocks();

    xil_printf("\r\n============================================================\r\n");
    xil_printf(" START-UP DIAGNOSTIC SUMMARY\r\n");
    xil_printf("============================================================\r\n");
    xil_printf(" PS GPIO initialized       : %s\r\n", GpioReady ? "YES" : "NO");
    xil_printf(" PS I2C0 initialized       : %s\r\n", IicReady ? "YES" : "NO");
    xil_printf(" PS I2C1 reset at D30      : %s\r\n",
               I2c1ResetWasAsserted ? "ASSERTED" : "RELEASED");
    xil_printf(" I2C1 reset released D35   : %s\r\n",
               I2c1ResetReleasedByDiagnostic ? "YES" : "NO/NOT NEEDED");
    xil_printf(" PS I2C1/EMIO initialized  : %s\r\n", PacReady ? "YES" : "NO");
    xil_printf(" PAC1944 PID transaction   : %s\r\n",
               PacResponding ? "PASS" : "FAIL/NOT RUN");
    xil_printf(" FH_Sen4K control safe     : %s\r\n",
               GmaxControlReady ? "YES" : "NO/UNAVAILABLE");
    xil_printf(" SATA 150 MHz             : %s\r\n",
               clock_result_string(LastSataClockResult));
    xil_printf(" USB3 100 MHz             : %s\r\n",
               clock_result_string(LastUsbClockResult));
    if (LastUsbClockResult == FH_CLOCK_PASS)
        xil_printf(" USB3 SuperSpeed link     : %s\r\n",
                   LastUsbFunctional ? "PASS" : "NOT ESTABLISHED");
    else
        xil_printf(" USB3 SuperSpeed link     : SKIPPED\r\n");
    xil_printf(" PCIe 100 MHz             : %s\r\n",
               clock_result_string(LastPcieClockResult));
    xil_printf("============================================================\r\n");
    xil_printf("Entering interactive menu. Failed start-up diagnostics do not\r\n");
    xil_printf("prevent menu access, so individual tests can be repeated.\r\n");
}

static void test_reset(void)
{
    xil_printf("\r\nEXTERNAL RESET TEST\r\n");
    xil_printf("-------------------\r\n");
    xil_printf("Press physical RESET button X2 now.\r\n");
    xil_printf("The application should stop immediately.\r\n");
    xil_printf("\r\nWaiting for reset...\r\n");

    while (1) {
        xil_printf(".");
        usleep(250000U);
    }
}

/* v18: on-chip GMAX3412 emulator smoke test. Requires the emulator BIT/XSA.
 * PS PL clock must be enabled at 100 MHz and PL resets released. Standalone
 * BSP must map the AXI peripheral region as Device memory. Polling is bounded;
 * it cannot recover from an AXI access to absent/unclocked hardware that hangs.
 * No physical sensor control or receiver register is accessed by this test.
 */
#define GMAX_EMU_BASE       ((UINTPTR)0xA0030000U)
#define GMAX_EMU_ID         0x00U
#define GMAX_EMU_COMMAND    0x04U
#define GMAX_EMU_STATUS     0x08U
#define GMAX_EMU_EXPOSURE   0x0CU
#define GMAX_EMU_BLANKING   0x10U
#define GMAX_EMU_SEED       0x14U
#define GMAX_EMU_WIDTH      0x18U
#define GMAX_EMU_HEIGHT     0x1CU
#define GMAX_EMU_ACCEPTED   0x20U
#define GMAX_EMU_REJECTED   0x24U
#define GMAX_EMU_FRAMES     0x28U
#define GMAX_EMU_ERRORS     0x2CU
#define GMAX_EMU_PIXELS     0x30U
#define GMAX_EMU_LINES      0x34U
#define GMAX_EMU_CHECKSUM   0x38U
#define GMAX_EMU_CLOCK_HZ   0x3CU

static u32 gmax_emu_read(u32 Offset)
{
    u32 Value;
    __asm__ volatile("dsb sy" ::: "memory");
    Value = Xil_In32(GMAX_EMU_BASE + Offset);
    __asm__ volatile("dsb sy" ::: "memory");
    return Value;
}

static void gmax_emu_write(u32 Offset, u32 Value)
{
    Xil_Out32(GMAX_EMU_BASE + Offset, Value);
    __asm__ volatile("dsb sy" ::: "memory");
}

static int gmax_emu_wait(u32 Offset, u32 Mask, u32 Expected, const char *Stage)
{
    u32 Poll, Value = 0U;
    /* Up to one second of delays, plus MMIO/loop overhead. */
    for (Poll = 0U; Poll <= 1000U; ++Poll) {
        Value = gmax_emu_read(Offset);
        if ((Value & Mask) == Expected)
            return XST_SUCCESS;
        if (Poll != 1000U)
            usleep(1000U);
    }
    xil_printf("  FAIL: timeout during %s; offset=0x%02lX value=0x%08lX\r\n",
               Stage, (unsigned long)Offset, (unsigned long)Value);
    return XST_FAILURE;
}

static void test_gmax3412_emulator(void)
{
    u32 Id, Frames, Errors, Accepted, Rejected;
    u32 FinalFrames, FinalErrors, FinalAccepted, FinalRejected;
    u32 Pixels, Lines, Checksum, Status;
    int Passed = 0;

    xil_printf("\r\nGMAX3412 EMULATOR SMOKE TEST (on-chip checker)\r\n");
    xil_printf("Requires the emulator bitstream, PS PL clock and released PL resets.\r\n");
    if (!gmax_pl_ready()) {
        xil_printf("  SKIPPED: PL configuration is not ready (DONE/EOS).\r\n");
        return;
    }
    xil_printf("  MMIO READ emulator ID @ 0xA0030000 ...\r\n");
    Id = gmax_emu_read(GMAX_EMU_ID);
    if (Id != 0x34120001U) {
        xil_printf("  FAIL: ID=0x%08lX; expected 0x34120001. No commands sent.\r\n",
                   (unsigned long)Id);
        return;
    }
    if (gmax_emu_read(GMAX_EMU_WIDTH) != 4096U ||
        gmax_emu_read(GMAX_EMU_HEIGHT) != 3072U ||
        gmax_emu_read(GMAX_EMU_CLOCK_HZ) != 120000000U) {
        xil_printf("  FAIL: unexpected geometry or advertised clock. No commands sent.\r\n");
        return;
    }

    gmax_emu_write(GMAX_EMU_COMMAND, 4U); /* STOP; finish any earlier frame. */
    if (gmax_emu_wait(GMAX_EMU_STATUS, 6U, 0U, "initial stop") != XST_SUCCESS)
        goto cleanup;
    usleep(1000U); /* Allow the previous checker result to commit. */
    Frames = gmax_emu_read(GMAX_EMU_FRAMES);
    Errors = gmax_emu_read(GMAX_EMU_ERRORS);
    Accepted = gmax_emu_read(GMAX_EMU_ACCEPTED);
    Rejected = gmax_emu_read(GMAX_EMU_REJECTED);

    gmax_emu_write(GMAX_EMU_COMMAND, 1U); /* INIT */
    if (gmax_emu_wait(GMAX_EMU_STATUS, 1U, 1U, "initialization") != XST_SUCCESS)
        goto cleanup;
    gmax_emu_write(GMAX_EMU_EXPOSURE, 120000U); /* 1 ms at 120 MHz */
    gmax_emu_write(GMAX_EMU_BLANKING, 16U);
    gmax_emu_write(GMAX_EMU_SEED, 7U);
    if (gmax_emu_read(GMAX_EMU_EXPOSURE) != 120000U ||
        gmax_emu_read(GMAX_EMU_BLANKING) != 16U ||
        gmax_emu_read(GMAX_EMU_SEED) != 7U) {
        xil_printf("  FAIL: exposure/blanking/seed readback mismatch.\r\n");
        goto cleanup;
    }
    gmax_emu_write(GMAX_EMU_COMMAND, 2U); /* START */
    if (gmax_emu_wait(GMAX_EMU_STATUS, 3U, 3U, "arming") != XST_SUCCESS)
        goto cleanup;
    gmax_emu_write(GMAX_EMU_COMMAND, 8U); /* Separate TRIGGER command */
    if (gmax_emu_wait(GMAX_EMU_FRAMES, 0xFFFFFFFFU,
                      (u32)(Frames + 1U), "frame completion") != XST_SUCCESS)
        goto cleanup;

    FinalFrames = gmax_emu_read(GMAX_EMU_FRAMES);
    FinalErrors = gmax_emu_read(GMAX_EMU_ERRORS);
    FinalAccepted = gmax_emu_read(GMAX_EMU_ACCEPTED);
    FinalRejected = gmax_emu_read(GMAX_EMU_REJECTED);
    Pixels = gmax_emu_read(GMAX_EMU_PIXELS);
    Lines = gmax_emu_read(GMAX_EMU_LINES);
    Checksum = gmax_emu_read(GMAX_EMU_CHECKSUM);
    Status = gmax_emu_read(GMAX_EMU_STATUS);
    xil_printf("  Pixels=%lu (12582912), lines=%lu (3072), checksum=0x%08lX (7FA00000)\r\n",
               (unsigned long)Pixels, (unsigned long)Lines, (unsigned long)Checksum);
    xil_printf("  Deltas: frames=%lu accepted=%lu rejected=%lu errors=%lu; status=0x%08lX\r\n",
               (unsigned long)(u32)(FinalFrames - Frames),
               (unsigned long)(u32)(FinalAccepted - Accepted),
               (unsigned long)(u32)(FinalRejected - Rejected),
               (unsigned long)(u32)(FinalErrors - Errors), (unsigned long)Status);
    Passed = (FinalFrames == (u32)(Frames + 1U) &&
              FinalAccepted == (u32)(Accepted + 1U) &&
              FinalRejected == Rejected && FinalErrors == Errors &&
              Pixels == 12582912U && Lines == 3072U &&
              Checksum == 0x7FA00000U && (Status & 0x1CU) == 0x10U);

cleanup:
    gmax_emu_write(GMAX_EMU_COMMAND, 4U);
    if (gmax_emu_wait(GMAX_EMU_STATUS, 6U, 0U, "final disarm/idle") != XST_SUCCESS)
        Passed = 0;
    xil_printf("  %s: GMAX3412 emulator 4096 x 3072, 10-bit smoke test.\r\n",
               Passed ? "PASS" : "FAIL");
    /* Keep the documented test settings; leave acquisition disarmed. */
}


/* v19: three one-shot captures through AXI DMA S2MM into owned DDR storage.
 * Build against the capture XSA's A53 standalone BSP. HP0 is non-coherent:
 * flush before DMA, invalidate after completion, then inspect every pixel.
 * Do not run another DMA owner concurrently. No fixed DDR address is assumed.
 */
#define CAP_GPIO ((UINTPTR)0xA0040000U)
#define CAP_DMA  ((UINTPTR)0xA0050000U)
#define CAP_NPIX 12582912U
#define CAP_NBYTES (CAP_NPIX * 2U)
static struct {
    u32 before[16];
    u16 pixels[CAP_NPIX];
    u32 after[16];
} CaptureBuffer __attribute__((aligned(64)));

static void cap_write(UINTPTR Address, u32 Value)
{
    Xil_Out32(Address, Value);
    __asm__ volatile("dsb sy" ::: "memory");
}
static u32 cap_read(UINTPTR Address)
{
    u32 Value;
    __asm__ volatile("dsb sy" ::: "memory");
    Value = Xil_In32(Address);
    __asm__ volatile("dsb sy" ::: "memory");
    return Value;
}
static u32 cap_diag(u32 Enable, u32 Index)
{
    cap_write(CAP_GPIO, Enable | (Index << 4));
    return cap_read(CAP_GPIO + 8U);
}
static int cap_dma_reset(void)
{
    u32 Poll;
    cap_write(CAP_DMA + 0x30U, 4U);
    for (Poll=0U; Poll<1000U; ++Poll) {
        if (!(cap_read(CAP_DMA+0x30U)&4U)) return XST_SUCCESS;
        usleep(1000U);
    }
    xil_printf("  FAIL: DMA reset timeout.\r\n");
    return XST_FAILURE;
}
/* A53 physical counter: coarse software timing, not pin-level timing sign-off. */
static int CaptureOverflowOnly;
static int CaptureQuiet;
static u64 capture_us(void)
{
    u64 Count,Hz;
    __asm__ volatile("isb; mrs %0, cntpct_el0" : "=r"(Count));
    __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(Hz));
    return (Count/Hz)*1000000ULL+(Count%Hz)*1000000ULL/Hz;
}
static int capture_run(u32 Count, u32 Blank, u32 Exposure, int Timing)
{
    static const u32 Seeds[3] = {7U,991U,123U};
    static const u32 Blanks[3] = {1024U,2048U,512U};
    UINTPTR Address=(UINTPTR)&CaptureBuffer.pixels[0];
    u32 Frame,Poll,I,Expected,Sum,Mismatch,DmaStatus=0U,CapStatus=0U;
    u32 FramesBefore,ErrorsBefore,AcceptedBefore,RejectedBefore;
    u32 ExposureBefore=0U,BlankBefore=0U,SeedBefore=0U;
    int Complete,Passed=0,HaveSettings=0;
    u64 Started=0, Elapsed, ExpectedUs;
    u32 TimingSequence=0;
    CaptureOverflowOnly=0;
    xil_printf("\r\nGMAX3412 DDR CAPTURE TEST - full-frame verification\r\n");
    xil_printf("Requires capture BIT/XSA and initialized PS HP0 DDR path.\r\n");
    if (!gmax_pl_ready()) {xil_printf("  SKIPPED: PL not ready.\r\n");return 0;}
    if (Address >= (UINTPTR)0x80000000U || Address > (UINTPTR)0x80000000U-CAP_NBYTES) {
        xil_printf("  FAIL: DMA buffer must reside in mapped low DDR below 2 GiB.\r\n");return 0;
    }
    xil_printf("  MMIO READ capture ID @ 0xA0040008 ...\r\n");
    if (cap_diag(0U,1U)!=0x3412CA01U || cap_diag(0U,7U)!=CAP_NBYTES ||
        !(cap_diag(0U,8U)&1U) || gmax_emu_read(GMAX_EMU_ID)!=0x34120001U) {
        xil_printf("  FAIL: capture/emulator identity or buffer size mismatch.\r\n");return 0;
    }
    if(Timing==2 && gmax_emu_read(0x40U)!=0x544D0001U) {
        xil_printf("  FAIL: hardware timing monitor absent; load the Timing bitstream.\r\n");return 0;
    }
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    if (gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"stop before DDR")!=XST_SUCCESS) goto cleanup;
    ExposureBefore=gmax_emu_read(GMAX_EMU_EXPOSURE);
    BlankBefore=gmax_emu_read(GMAX_EMU_BLANKING);
    SeedBefore=gmax_emu_read(GMAX_EMU_SEED);HaveSettings=1;
    gmax_emu_write(GMAX_EMU_COMMAND,1U);
    if (gmax_emu_wait(GMAX_EMU_STATUS,1U,1U,"DDR initialization")!=XST_SUCCESS) goto cleanup;
    xil_printf("  DDR buffer=0x%08lX bytes=%lu; little-endian 16-bit pixels.\r\n",
               (unsigned long)Address,(unsigned long)CAP_NBYTES);
    for(Frame=0U;Frame<Count;++Frame) {
        cap_write(CAP_GPIO,4U);usleep(1000U);cap_write(CAP_GPIO,0U);
        if(cap_dma_reset()!=XST_SUCCESS) goto cleanup;
        for(I=0U;I<16U;++I) {CaptureBuffer.before[I]=0xA55A1234U;CaptureBuffer.after[I]=0x5AA54321U;}
        for(I=0U;I<CAP_NPIX;++I) CaptureBuffer.pixels[I]=0xFFFFU;
        Xil_DCacheFlushRange((INTPTR)&CaptureBuffer,sizeof(CaptureBuffer));
        gmax_emu_write(GMAX_EMU_EXPOSURE,(Exposure ? Exposure : 120000U*(Frame%3U+1U)));
        gmax_emu_write(GMAX_EMU_BLANKING,(Blank ? Blank : Blanks[Frame%3U]));
        gmax_emu_write(GMAX_EMU_SEED,((Seeds[Frame%3U]+(Blank ? Frame*17U : 0U))&1023U));
        FramesBefore=gmax_emu_read(GMAX_EMU_FRAMES);
        ErrorsBefore=gmax_emu_read(GMAX_EMU_ERRORS);
        AcceptedBefore=gmax_emu_read(GMAX_EMU_ACCEPTED);
        RejectedBefore=gmax_emu_read(GMAX_EMU_REJECTED);
        cap_write(CAP_DMA+0x34U,0x7000U); /* clear W1C interrupt status */
        cap_write(CAP_DMA+0x30U,1U);     /* Run S2MM, polling mode */
        cap_write(CAP_DMA+0x48U,(u32)Address);
        cap_write(CAP_DMA+0x58U,CAP_NBYTES); /* arm receive */
        cap_write(CAP_GPIO,1U); /* select emulator and arm bridge */
        for(Poll=0U;Poll<1000U;++Poll) {
            if(cap_diag(1U,0U)&1U) break;
            usleep(1000U);
        }
        if(Poll==1000U) {xil_printf("  FAIL: capture arm timeout.\r\n");goto cleanup;}
        gmax_emu_write(GMAX_EMU_COMMAND,2U);
        if(gmax_emu_wait(GMAX_EMU_STATUS,3U,3U,"DDR arm")!=XST_SUCCESS) goto cleanup;
        if(Timing==2) TimingSequence=gmax_emu_read(0x44U);
        Started=capture_us();
        gmax_emu_write(GMAX_EMU_COMMAND,8U);
        Complete=0;
        for(Poll=0U;Poll<2000U;++Poll) {
            DmaStatus=cap_read(CAP_DMA+0x34U);CapStatus=cap_diag(1U,0U);
            if((DmaStatus&0x770U) || (CapStatus&0x38U)) break;
            if((DmaStatus&0x1002U)==0x1002U && (CapStatus&0x44U)==0x44U) {Complete=1;break;}
            usleep(1000U);
        }
        if(!Complete || cap_diag(1U,2U)!=CAP_NBYTES || cap_read(CAP_DMA+0x58U)!=CAP_NBYTES) {
            CaptureOverflowOnly=((CapStatus&8U)!=0U && (DmaStatus&0x770U)==0U && (CapStatus&0x20U)==0U);
            xil_printf("  FAIL: DMA/capture completion: DMA=0x%08lX CAP=0x%08lX\r\n",
                       (unsigned long)DmaStatus,(unsigned long)CapStatus);goto cleanup;
        }
        if(gmax_emu_wait(GMAX_EMU_FRAMES,0xFFFFFFFFU,(u32)(FramesBefore+1U),"DDR checker")!=XST_SUCCESS) goto cleanup;
        if(gmax_emu_read(GMAX_EMU_ERRORS)!=ErrorsBefore ||
           gmax_emu_read(GMAX_EMU_ACCEPTED)!=(u32)(AcceptedBefore+1U) ||
           gmax_emu_read(GMAX_EMU_REJECTED)!=RejectedBefore ||
           !(gmax_emu_read(GMAX_EMU_STATUS)&16U)) {
            xil_printf("  FAIL: source checker/trigger counters.\r\n");goto cleanup;
        }
        Elapsed=capture_us()-Started;
        if(Timing==2) {
            u32 E=Exposure ? Exposure : 120000U*(Frame%3U+1U);
            u32 B=Blank ? Blank : Blanks[Frame%3U];
            u32 Seq=gmax_emu_read(0x44U),Exp=gmax_emu_read(0x48U);
            u32 Lmin=gmax_emu_read(0x4CU),Lmax=gmax_emu_read(0x50U);
            u32 Bmin=gmax_emu_read(0x54U),Bmax=gmax_emu_read(0x58U);
            u32 Fc=gmax_emu_read(0x5CU),Lc=gmax_emu_read(0x60U);
            if(Seq!=TimingSequence+1U || gmax_emu_read(0x44U)!=Seq || Exp!=E ||
               Lmin!=256U || Lmax!=256U || Bmin!=B || Bmax!=B ||
               Fc!=3072U*256U+3071U*B || Lc!=3072U) {
                xil_printf("  FAIL: hardware timing seq=%lu exp=%lu line=%lu/%lu blank=%lu/%lu frame=%lu lines=%lu\r\n",
                    (unsigned long)Seq,(unsigned long)Exp,(unsigned long)Lmin,(unsigned long)Lmax,
                    (unsigned long)Bmin,(unsigned long)Bmax,(unsigned long)Fc,(unsigned long)Lc);goto cleanup;
            }
            if(!CaptureQuiet || (Frame+1U)%10U==0U || Frame+1U==Count)
                xil_printf("  HW timing PASS: exposure=%lu line=%lu blank=%lu frame=%lu cycles; seq=%lu\r\n",
                    (unsigned long)Exp,(unsigned long)Lmin,(unsigned long)Bmin,(unsigned long)Fc,(unsigned long)Seq);
        }

        ExpectedUs=((u64)(Exposure ? Exposure : 120000U*(Frame%3U+1U))+
                    3072ULL*256ULL+3071ULL*(Blank ? Blank : Blanks[Frame%3U]))/120ULL;
        if(!CaptureQuiet) xil_printf("  Timing: observed=%lu us model=%lu us (includes polling/DMA tail)\r\n",
                   (unsigned long)Elapsed,(unsigned long)ExpectedUs);
        if(Timing && (Elapsed+100U<ExpectedUs || Elapsed>ExpectedUs+20000U)) {
            xil_printf("  FAIL: coarse frame timing outside tolerance.\r\n");goto cleanup;
        }
        Xil_DCacheInvalidateRange((INTPTR)&CaptureBuffer,sizeof(CaptureBuffer));
        Sum=0U;Mismatch=0U;
        for(I=0U;I<CAP_NPIX;++I) {
            Expected=((I&4095U)+(I>>12)+((Seeds[Frame%3U]+(Blank ? Frame*17U : 0U))&1023U))&1023U;
            if(CaptureBuffer.pixels[I]!=Expected) {
                if(Mismatch<4U) xil_printf("  Pixel %lu: got %lu expected %lu\r\n",
                    (unsigned long)I,(unsigned long)CaptureBuffer.pixels[I],(unsigned long)Expected);
                ++Mismatch;
            }
            Sum+=CaptureBuffer.pixels[I];
        }
        for(I=0U;I<16U;++I) if(CaptureBuffer.before[I]!=0xA55A1234U || CaptureBuffer.after[I]!=0x5AA54321U) ++Mismatch;
        if(Mismatch || Sum!=0x7FA00000U) {
            xil_printf("  FAIL: DDR mismatches=%lu checksum=0x%08lX\r\n",(unsigned long)Mismatch,(unsigned long)Sum);goto cleanup;
        }
        if(!CaptureQuiet || (Frame+1U)%10U==0U || Frame+1U==Count) xil_printf("  Frame %lu PASS: all %lu pixels, guard regions, checksum 0x%08lX; seed=%lu blank=%lu\r\n",
                   (unsigned long)(Frame+1U),(unsigned long)CAP_NPIX,(unsigned long)Sum,
                   (unsigned long)((Seeds[Frame%3U]+(Blank ? Frame*17U : 0U))&1023U),(unsigned long)(Blank ? Blank : Blanks[Frame%3U]));
        cap_write(CAP_GPIO,0U);usleep(1000U);
    }
    Passed=1;
cleanup:
    cap_write(CAP_GPIO,4U);usleep(1000U);
    if(cap_dma_reset()!=XST_SUCCESS) {Passed=0;CaptureOverflowOnly=0;}
    cap_write(CAP_GPIO,0U);
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"DDR cleanup")!=XST_SUCCESS) {Passed=0;CaptureOverflowOnly=0;}
    if(HaveSettings) {
        gmax_emu_write(GMAX_EMU_EXPOSURE,ExposureBefore);
        gmax_emu_write(GMAX_EMU_BLANKING,BlankBefore);
        gmax_emu_write(GMAX_EMU_SEED,SeedBefore);
    }
    xil_printf("  %s: GMAX3412 DDR capture and pixel verification.\r\n",Passed?"PASS":"FAIL");
    return Passed;
}

/* Deliberately leave DMA reset so a full source frame overflows the FIFO.
 * Also check one busy trigger is rejected. Always drain source and flush. */
static int capture_overflow_test(void)
{
    u32 P,Status=0,A,R,E,B,S; int Pass=0;
    E=gmax_emu_read(GMAX_EMU_EXPOSURE);
    B=gmax_emu_read(GMAX_EMU_BLANKING);S=gmax_emu_read(GMAX_EMU_SEED);
    cap_write(CAP_GPIO,4U);usleep(1000U);
    if(cap_dma_reset()!=XST_SUCCESS) goto done;
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"fault idle")!=XST_SUCCESS) goto done;
    A=gmax_emu_read(GMAX_EMU_ACCEPTED);R=gmax_emu_read(GMAX_EMU_REJECTED);
    gmax_emu_write(GMAX_EMU_COMMAND,8U);
    if(gmax_emu_wait(GMAX_EMU_REJECTED,0xFFFFFFFFU,R+1U,"disarmed trigger rejection")!=XST_SUCCESS) goto done;
    if(gmax_emu_read(GMAX_EMU_ACCEPTED)!=A) goto done;
    gmax_emu_write(GMAX_EMU_EXPOSURE,12000000U);
    gmax_emu_write(GMAX_EMU_BLANKING,512U);
    cap_write(CAP_GPIO,1U);
    for(P=0;P<1000U;++P) {if(cap_diag(1U,0U)&1U) break;usleep(1000U);}
    if(P==1000U) goto done;
    gmax_emu_write(GMAX_EMU_COMMAND,2U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,3U,3U,"fault arm")!=XST_SUCCESS) goto done;
    A=gmax_emu_read(GMAX_EMU_ACCEPTED);R=gmax_emu_read(GMAX_EMU_REJECTED);
    gmax_emu_write(GMAX_EMU_COMMAND,8U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,4U,4U,"fault busy")!=XST_SUCCESS) goto done;
    gmax_emu_write(GMAX_EMU_COMMAND,8U);
    if(gmax_emu_wait(GMAX_EMU_REJECTED,0xFFFFFFFFU,R+1U,"busy trigger rejection")!=XST_SUCCESS) goto done;
    for(P=0;P<2000U;++P) {Status=cap_diag(1U,0U);if(Status&8U) break;usleep(1000U);}
    Pass=(Status&8U) && gmax_emu_read(GMAX_EMU_ACCEPTED)==A+1U;
done:
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"fault drain")!=XST_SUCCESS) Pass=0;
    cap_write(CAP_GPIO,4U);usleep(1000U);
    if(cap_dma_reset()!=XST_SUCCESS) Pass=0;
    cap_write(CAP_GPIO,0U);usleep(1000U);
    if(cap_diag(0U,0U)&0x38U) Pass=0;
    gmax_emu_write(GMAX_EMU_EXPOSURE,E);gmax_emu_write(GMAX_EMU_BLANKING,B);gmax_emu_write(GMAX_EMU_SEED,S);
    xil_printf("  %s: forced FIFO overflow, disarmed/busy trigger rejection, flag reset; status=0x%08lX\r\n",Pass?"PASS":"FAIL",(unsigned long)Status);
    return Pass;
}
static void test_gmax3412_regression(void)
{
    static const u32 Sweep[]={512U,384U,320U,288U,256U,192U,128U,16U};
    u32 I,Fastest=0U; int Boundary=0;
    xil_printf("\r\nGMAX3412 REGRESSION v20: stress, timing, overflow, recovery\r\n");
    /* Establish identity, initialization and a known-good frame first. */
    if(!capture_run(1U,512U,120000U,1)) return;
    if(!capture_run(12U,512U,120000U,1)) return;
    if(!capture_run(1U,1024U,12000000U,1)) return;
    if(!capture_overflow_test()) return;
    if(!capture_run(2U,512U,120000U,1)) return;
    xil_printf("  Bandwidth sweep: a failed capture marks a candidate boundary, not a qualified limit.\r\n");
    for(I=0U;I<sizeof(Sweep)/sizeof(Sweep[0]);++I) {
        xil_printf("  Sweep blank=%lu cycles\r\n",(unsigned long)Sweep[I]);
        if(!capture_run(2U,Sweep[I],120000U,1)) {
            if(!CaptureOverflowOnly) {xil_printf("  FAIL: sweep failure was not isolated FIFO overflow.\r\n");return;}
            Boundary=1;break;
        }
        Fastest=Sweep[I];
    }
    /* Recovery is mandatory even when sweep finds no boundary. */
    if(!capture_run(3U,512U,120000U,1)) return;
    xil_printf("  PASS: baseline stress, coarse timing, forced overflow, busy trigger and recovery.\r\n");
    xil_printf("  Sweep: lowest passing blank=%lu cycles; boundary observed=%u.\r\n",(unsigned long)Fastest,(unsigned int)Boundary);
    xil_printf("  Software timings include polling latency; no maximum-rate or pin-timing sign-off.\r\n");
}

static void test_gmax3412_qualification(void)
{
    int Pass=0;
    xil_printf("\r\nGMAX3412 QUALIFICATION v21: repeated full frames + hardware timing\r\n");
    xil_printf("  Each frame is verified before the next trigger; this is not gapless streaming.\r\n");
    CaptureQuiet=1;
    if(!capture_run(1U,512U,1U,2)) goto done;
    if(!capture_run(1U,512U,12000000U,2)) goto done;
    if(!capture_run(32U,512U,120000U,2)) goto done;
    if(!capture_run(100U,320U,120000U,2)) goto done;
    if(!capture_run(100U,288U,120000U,2)) goto done;
    if(!capture_run(100U,256U,120000U,2)) goto done;
    if(!capture_overflow_test()) goto done;
    if(!capture_run(3U,512U,120000U,2)) goto done;
    Pass=1;
done:
    CaptureQuiet=0;
    xil_printf("  %s: v21 repeated-capture qualification and hardware timing.\r\n",Pass?"PASS":"FAIL");
    xil_printf("  Pin electrical timing and gapless DDR streaming are outside this test.\r\n");
}

int main(void)
{
    char Command;


    xil_printf("\r\n\r\n");
    xil_printf("========================================\r\n");
    xil_printf(" FH_Carrier Prototype Bring-Up\r\n");
    xil_printf(" PZ-ZU7EV / Cortex-A53_0\r\n");
    xil_printf(" PAC1944 + REFCLK + FH_Sen4K/GMAX3412-A + emulator/DDR diagnostics v21\r\n");
    xil_printf("========================================\r\n");

    run_startup_diagnostics();

    show_menu();

    while (1) {
        Command = inbyte();

        if ((unsigned char)Command != 0x1BU) {
            if ((Command != '\r') && (Command != '\n'))
                xil_printf("\r\n> %c\r\n", Command);
        }

        switch (Command) {
        case '1':
            test_power_good();
            break;

        case '2':
            dump_eeprom();
            break;

        case '3':
            show_EUI48();
            break;

        case '4':
            test_pac1944_id();
            break;

        case '5':
            test_pac1944_measurements();
            break;

        case '6':
            run_startup_diagnostics();
            break;

        case '7':
            test_differential_clocks();
            break;

        case '8':
            gmax_menu();
            break;

        case '9':
            test_gmax3412_emulator();
            break;

        case 'q':
        case 'Q':
            test_gmax3412_qualification();
            break;

        case 't':
        case 'T':
            test_gmax3412_regression();
            break;

        case 'd':
        case 'D':
            (void)capture_run(3U,0U,0U,0);
            break;

        case 'r':
        case 'R':
            test_reset();
            break;

        case 'h':
        case 'H':
        case '?':
            show_menu();
            break;

        case 0x1B:
            xil_printf("\r\n");
            xil_printf("ESC received.\r\n");
            xil_printf("Exiting FH_Carrier bring-up test.\r\n");
            return 0;

        case '\r':
        case '\n':
            break;

        default:
            xil_printf("Unknown command. Press H for menu.\r\n");
            break;
        }
    }
}
