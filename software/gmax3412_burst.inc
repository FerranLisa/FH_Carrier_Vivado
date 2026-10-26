/* v23: finite hardware-scheduled burst, 4..119 guarded frames, <=3e9 bytes.
 * No CPU rearm/trigger in the acquisition loop. All slots retained until a
 * deliberate new B command. Requires the reserved-memory v23 linker script.
 */
#define BURST_GPIO ((UINTPTR)0xA0060000U)
#define BURST_STRIDE 25165952ULL
#define BURST_MAX 119U
extern char __gmax_reserved_layout_v23;
static u32 BurstControl;
static UINTPTR burst_slot(u32 N)
{
    return (UINTPTR)(N<74U ? 0x10000000ULL+N*BURST_STRIDE :
                              0x800000000ULL+(N-74U)*BURST_STRIDE);
}
static u32 burst_diag(u32 Bank)
{
    BurstControl=(BurstControl&~15U)|Bank;
    cap_write(BURST_GPIO,BurstControl);
    return cap_read(BURST_GPIO+8U);
}
static void burst_command(u32 Op,u32 Value)
{
    BurstControl=((BurstControl^0x80000000U)&0x80000000U)|(Op<<28)|(Value<<8)|1U;
    cap_write(BURST_GPIO,BurstControl);
    usleep(2U);
}
static void test_gmax3412_burst(void)
{
    u32 N=0U,Digits=0U,I,F,S,Sum,Frames,Errors,Accepted,Rejected,Seq;
    u32 OldExp,OldBlank,OldSeed;u64 Started;
    int BadInput=0;char Key;
    xil_printf("\r\nGMAX3412 AUTONOMOUS BURST v23 - configurable retained frames\r\n");
    xil_printf("Frames to store [4..119, Enter=4; ESC cancels]: ");
    for(;;) {
        Key=inbyte();
        if(Key==27) {xil_printf(" cancelled\r\n");return;}
        if(Key=='\r'||Key=='\n') break;
        if(Key>='0'&&Key<='9'&&Digits<3U) {N=N*10U+(u32)(Key-'0');++Digits;outbyte(Key);}
        else BadInput=1;
    }
    if(!Digits) N=4U;
    xil_printf("\r\n");
    if(BadInput||N<4U||N>BURST_MAX||N*BURST_STRIDE>3000000000ULL) {
        xil_printf("  REJECTED: capacity must be 4..119 whole frames.\r\n");return;
    }
    if((UINTPTR)&__gmax_reserved_layout_v23!=0x10000000ULL) {
        xil_printf("  FAIL: reserved DDR linker contract missing.\r\n");return;
    }
    if(!gmax_pl_ready()) return;
    BurstControl=cap_read(BURST_GPIO);
    if(burst_diag(0U)!=0x34125301U || burst_diag(8U)!=BURST_MAX || burst_diag(9U)!=BURST_STRIDE) {
        xil_printf("  FAIL: load v23 Scheduler BIT/XSA.\r\n");return;
    }
    if(burst_diag(1U)&1U) {xil_printf("  FAIL: scheduler already owns DMA; reset/relaunch required.\r\n");return;}
    xil_printf("  Capacity=%lu frames, storage=%lu bytes incl. guards; payload/frame=%lu bytes.\r\n",
               (unsigned long)N,(unsigned long)(N*BURST_STRIDE),(unsigned long)CAP_NBYTES);
    xil_printf("  Preparing reserved DDR; previous burst contents will be replaced.\r\n");
    for(F=0U;F<N;++F) {
        u32 *P=(u32*)burst_slot(F);
        for(I=0U;I<16U;++I) {P[I]=0xA55A1234U;P[16U+CAP_NBYTES/4U+I]=0x5AA54321U;}
        /* Poison makes skipped/partial writes visible, including a repeated run. */
        for(I=0U;I<CAP_NBYTES/4U;++I) P[16U+I]=0xFFFFFFFFU;
        Xil_DCacheFlushRange((INTPTR)P,(u32)BURST_STRIDE);
        if((F+1U)%8U==0U||F+1U==N) xil_printf("  Prepared %lu/%lu\r\n",(unsigned long)(F+1U),(unsigned long)N);
    }
    OldExp=gmax_emu_read(GMAX_EMU_EXPOSURE);OldBlank=gmax_emu_read(GMAX_EMU_BLANKING);OldSeed=gmax_emu_read(GMAX_EMU_SEED);
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"burst stop")!=XST_SUCCESS) return;
    gmax_emu_write(GMAX_EMU_COMMAND,1U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,1U,1U,"burst init")!=XST_SUCCESS) return;
    gmax_emu_write(GMAX_EMU_EXPOSURE,120000U);gmax_emu_write(GMAX_EMU_BLANKING,1024U);
    gmax_emu_write(GMAX_EMU_COMMAND,2U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,3U,3U,"burst arm")!=XST_SUCCESS) goto cleanup;
    Frames=gmax_emu_read(GMAX_EMU_FRAMES);Errors=gmax_emu_read(GMAX_EMU_ERRORS);
    Accepted=gmax_emu_read(GMAX_EMU_ACCEPTED);Rejected=gmax_emu_read(GMAX_EMU_REJECTED);Seq=gmax_emu_read(0x44U);
    burst_command(1U,N);if(burst_diag(4U)!=0U) goto fail;
    Started=capture_us();burst_command(2U,0U);
    do {
        S=burst_diag(1U);
        if(capture_us()-Started>15000000ULL) {
            burst_command(3U,0U);
            xil_printf("  FAIL: scheduler timeout; requested graceful stop. Relaunch before other tests.\r\n");
            /* Ownership cannot safely be reclaimed from an unresponsive bus. */
            while(burst_diag(1U)&1U) usleep(1000U);
            goto fail;
        }
        usleep(1000U);
    } while(S&1U);
    if((S&7U)!=2U || burst_diag(3U)!=N || burst_diag(4U)!=0U ||
       gmax_emu_read(GMAX_EMU_FRAMES)-Frames!=N || gmax_emu_read(GMAX_EMU_ERRORS)!=Errors ||
       gmax_emu_read(GMAX_EMU_ACCEPTED)-Accepted!=N || gmax_emu_read(GMAX_EMU_REJECTED)!=Rejected ||
       gmax_emu_read(0x44U)-Seq!=N || gmax_emu_read(0x48U)!=120000U ||
       gmax_emu_read(0x4CU)!=256U || gmax_emu_read(0x50U)!=256U ||
       gmax_emu_read(0x54U)!=1024U || gmax_emu_read(0x58U)!=1024U ||
       gmax_emu_read(0x5CU)!=3931136U || gmax_emu_read(0x60U)!=3072U) goto fail;
    xil_printf("  Autonomous capture complete: %lu frames, %lu hardware cycles. Verifying retained storage...\r\n",
               (unsigned long)N,(unsigned long)burst_diag(5U));
    for(F=0U;F<N;++F) {
        u32 *P=(u32*)burst_slot(F);u16 *Pixels=(u16*)(P+16U);u32 Seed=(7U+37U*F)&1023U;
        Xil_DCacheInvalidateRange((INTPTR)P,(u32)BURST_STRIDE);
        for(I=0U;I<16U;++I) if(P[I]!=0xA55A1234U||P[16U+CAP_NBYTES/4U+I]!=0x5AA54321U) goto fail;
        Sum=0U;
        for(I=0U;I<CAP_NPIX;++I) {
            u32 Expected=((I%4096U)+(I/4096U)+Seed)&1023U;
            if(Pixels[I]!=Expected) {
                xil_printf("  Pixel mismatch frame=%lu index=%lu got=%lu expected=%lu\r\n",
                           (unsigned long)F,(unsigned long)I,(unsigned long)Pixels[I],(unsigned long)Expected);goto fail;
            }
            Sum+=Pixels[I];
        }
        if(Sum!=0x7FA00000U) goto fail;
        xil_printf("  Frame %lu/%lu PASS: all pixels, guards, checksum; seed=%lu address=0x%lx\r\n",
                   (unsigned long)(F+1U),(unsigned long)N,(unsigned long)Seed,(unsigned long)(UINTPTR)Pixels);
    }
    xil_printf("  PASS: autonomous burst; all %lu frames retained and verified.\r\n",(unsigned long)N);
    goto cleanup;
fail:
    xil_printf("  FAIL: autonomous burst status=0x%08lx error=%lu completed=%lu DMA=0x%08lx capture=0x%08lx\r\n",
               (unsigned long)burst_diag(1U),(unsigned long)burst_diag(4U),(unsigned long)burst_diag(3U),
               (unsigned long)burst_diag(6U),(unsigned long)burst_diag(7U));
cleanup:
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    gmax_emu_write(GMAX_EMU_EXPOSURE,OldExp);gmax_emu_write(GMAX_EMU_BLANKING,OldBlank);gmax_emu_write(GMAX_EMU_SEED,OldSeed);
}
