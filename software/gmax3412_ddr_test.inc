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
static void test_gmax3412_ddr(void)
{
    static const u32 Seeds[3] = {7U,991U,123U};
    static const u32 Blanks[3] = {1024U,2048U,512U};
    UINTPTR Address=(UINTPTR)&CaptureBuffer.pixels[0];
    u32 Frame,Poll,I,Expected,Sum,Mismatch,DmaStatus=0U,CapStatus=0U;
    u32 FramesBefore,ErrorsBefore,AcceptedBefore,RejectedBefore;
    u32 ExposureBefore=0U,BlankBefore=0U,SeedBefore=0U;
    int Complete,Passed=0,HaveSettings=0;
    xil_printf("\r\nGMAX3412 DDR CAPTURE TEST - three full frames\r\n");
    xil_printf("Requires capture BIT/XSA and initialized PS HP0 DDR path.\r\n");
    if (!gmax_pl_ready()) {xil_printf("  SKIPPED: PL not ready.\r\n");return;}
    if (Address >= (UINTPTR)0x80000000U || Address > (UINTPTR)0x80000000U-CAP_NBYTES) {
        xil_printf("  FAIL: DMA buffer must reside in mapped low DDR below 2 GiB.\r\n");return;
    }
    xil_printf("  MMIO READ capture ID @ 0xA0040008 ...\r\n");
    if (cap_diag(0U,1U)!=0x3412CA01U || cap_diag(0U,7U)!=CAP_NBYTES ||
        !(cap_diag(0U,8U)&1U) || gmax_emu_read(GMAX_EMU_ID)!=0x34120001U) {
        xil_printf("  FAIL: capture/emulator identity or buffer size mismatch.\r\n");return;
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
    for(Frame=0U;Frame<3U;++Frame) {
        cap_write(CAP_GPIO,4U);usleep(1000U);cap_write(CAP_GPIO,0U);
        if(cap_dma_reset()!=XST_SUCCESS) goto cleanup;
        for(I=0U;I<16U;++I) {CaptureBuffer.before[I]=0xA55A1234U;CaptureBuffer.after[I]=0x5AA54321U;}
        for(I=0U;I<CAP_NPIX;++I) CaptureBuffer.pixels[I]=0xFFFFU;
        Xil_DCacheFlushRange((INTPTR)&CaptureBuffer,sizeof(CaptureBuffer));
        gmax_emu_write(GMAX_EMU_EXPOSURE,120000U*(Frame+1U));
        gmax_emu_write(GMAX_EMU_BLANKING,Blanks[Frame]);
        gmax_emu_write(GMAX_EMU_SEED,Seeds[Frame]);
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
        gmax_emu_write(GMAX_EMU_COMMAND,8U);
        Complete=0;
        for(Poll=0U;Poll<2000U;++Poll) {
            DmaStatus=cap_read(CAP_DMA+0x34U);CapStatus=cap_diag(1U,0U);
            if((DmaStatus&0x770U) || (CapStatus&0x38U)) break;
            if((DmaStatus&0x1002U)==0x1002U && (CapStatus&0x44U)==0x44U) {Complete=1;break;}
            usleep(1000U);
        }
        if(!Complete || cap_diag(1U,2U)!=CAP_NBYTES || cap_read(CAP_DMA+0x58U)!=CAP_NBYTES) {
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
        Xil_DCacheInvalidateRange((INTPTR)&CaptureBuffer,sizeof(CaptureBuffer));
        Sum=0U;Mismatch=0U;
        for(I=0U;I<CAP_NPIX;++I) {
            Expected=((I&4095U)+(I>>12)+Seeds[Frame])&1023U;
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
        xil_printf("  Frame %lu PASS: all %lu pixels, guard regions, checksum 0x%08lX; seed=%lu blank=%lu\r\n",
                   (unsigned long)(Frame+1U),(unsigned long)CAP_NPIX,(unsigned long)Sum,
                   (unsigned long)Seeds[Frame],(unsigned long)Blanks[Frame]);
        cap_write(CAP_GPIO,0U);usleep(1000U);
    }
    Passed=1;
cleanup:
    cap_write(CAP_GPIO,4U);usleep(1000U);
    if(cap_dma_reset()!=XST_SUCCESS) Passed=0;
    cap_write(CAP_GPIO,0U);
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"DDR cleanup")!=XST_SUCCESS) Passed=0;
    if(HaveSettings) {
        gmax_emu_write(GMAX_EMU_EXPOSURE,ExposureBefore);
        gmax_emu_write(GMAX_EMU_BLANKING,BlankBefore);
        gmax_emu_write(GMAX_EMU_SEED,SeedBefore);
    }
    xil_printf("  %s: GMAX3412 DDR capture and pixel verification.\r\n",Passed?"PASS":"FAIL");
}

