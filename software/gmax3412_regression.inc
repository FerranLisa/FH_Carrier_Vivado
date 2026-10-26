/* A53 physical counter: coarse software timing, not pin-level timing sign-off. */
static int CaptureOverflowOnly;
static u64 capture_us(void)
{
    u64 Count,Hz;
    __asm__ volatile("isb; mrs %0, cntpct_el0" : "=r"(Count));
    __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(Hz));
    return (Count/Hz)*1000000ULL+(Count%Hz)*1000000ULL/Hz;
}
/* RUNNER */
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
