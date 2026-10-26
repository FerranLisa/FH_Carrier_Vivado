/* v24 PL DDR4: 4..170 guarded frames. Stop before CPU readback. */
#include "xil_mmu.h"
#include "xuartps_hw.h"
#define PLR_GPIO ((UINTPTR)0xA0070000U)
#define PLR_BASE 0x1000000000ULL
#define PLR_BYTES 0x100000000ULL
#define PLR_MAX 170U
static u32 PlrControl;
static int PlrSkipLf;
static u32 plr_diag(u32 Bank)
{
    PlrControl=(PlrControl&~15U)|Bank;
    cap_write(PLR_GPIO,PlrControl);return cap_read(PLR_GPIO+8U);
}
static void plr_command(u32 Op,u32 Value)
{
    PlrControl=((PlrControl^0x80000000U)&0x80000000U)|(Op<<28)|((Value&0xFFFFFU)<<8)|1U;
    cap_write(PLR_GPIO,PlrControl);usleep(2U);
}
static int plr_read_number(const char *Prompt,u32 Default,u32 *Value)
{
    u32 N=0,Digits=0;int Bad=0;char C;
    xil_printf("%s",Prompt);
    for(;;) {
        C=inbyte();
        if(PlrSkipLf){PlrSkipLf=0;if(C=='\n')continue;}
        if(C==27){xil_printf(" cancelled\r\n");return 0;}
        if(C=='\r'||C=='\n'){PlrSkipLf=(C=='\r');break;}
        if(C>='0'&&C<='9'&&Digits<3U){N=N*10U+(u32)(C-'0');Digits++;outbyte(C);}else Bad=1;
    }
    xil_printf("\r\n");*Value=Digits?N:Default;return !Bad;
}
static int plr_bank_probe(void)
{
    /* Probe distinct address bits and the final word before any capture.
     * Flush/invalidate every location so cache cannot hide address aliasing. */
    UINTPTR A[34];u32 I,J=0;
    A[J++]=(UINTPTR)PLR_BASE;
    for(I=3;I<32;I++) A[J++]=(UINTPTR)(PLR_BASE+(1ULL<<I));
    A[J++]=(UINTPTR)(PLR_BASE+PLR_BYTES-8ULL);
    for(I=0;I<J;I++) {
        xil_printf("  DDR probe WRITE %lu/%lu @ 0x%lx ...\r\n",
                   (unsigned long)(I+1U),(unsigned long)J,(unsigned long)A[I]);
        *(volatile u64*)A[I]=0xD4D4000000000000ULL+I;
        xil_printf("  DDR probe FLUSH ...\r\n");
        Xil_DCacheFlushRange(A[I],8U);
    }
    for(I=0;I<J;I++) {
        xil_printf("  DDR probe INVALIDATE %lu/%lu @ 0x%lx ...\r\n",
                   (unsigned long)(I+1U),(unsigned long)J,(unsigned long)A[I]);
        Xil_DCacheInvalidateRange(A[I],8U);
        xil_printf("  DDR probe READ ...\r\n");
        if(*(volatile u64*)A[I]!=0xD4D4000000000000ULL+I) {
            xil_printf("  FAIL: PL DDR address alias/readback at 0x%lx\r\n",(unsigned long)A[I]);return 0;
        }
    }
    xil_printf("  PASS: 4 GiB address-bit probe, including final bank word.\r\n");return 1;
}
static void test_gmax3412_pl_ring(void)
{
    u32 N,F,I,S,Total,Retained,First,Sum,Seed,Target,Mode;
    u32 OldExp,OldBlank,OldSeed,Frames,Errors,Accepted,Rejected;
    u64 Started;int StopSent=0;
    xil_printf("\r\nGMAX3412 PL DDR4 ROLLING BUFFER v24\r\n");
    if(!plr_read_number("Stored frames [4..170, Enter=4; ESC cancels]: ",4U,&N)||N<4U||N>PLR_MAX||N*BURST_STRIDE>PLR_BYTES) {
        xil_printf("  REJECTED: capacity must be 4..170 whole guarded frames.\r\n");return;
    }
    if(!plr_read_number("Mode [Enter/0=two-wrap qualification; 1=continuous, ESC stops capture]: ",0U,&Mode)||Mode>1U) return;
    if(!gmax_pl_ready()) return;
    xil_printf("  MMIO READ PL ring ID @ 0xA0070008 ...\r\n");
    PlrControl=cap_read(PLR_GPIO);
    if(plr_diag(0)!=0x34125224U||plr_diag(8)!=PLR_MAX||plr_diag(9)!=BURST_STRIDE) {
        xil_printf("  FAIL: load v24 PL-DDR BIT/XSA.\r\n");return;
    }
    BurstControl=cap_read(BURST_GPIO);
    if((plr_diag(1)|burst_diag(1))&1U) {xil_printf("  FAIL: a scheduler owns capture/DMA.\r\n");return;}
    Started=capture_us();
    while(!plr_diag(12)) if(capture_us()-Started>10000000ULL) {
        xil_printf("  FAIL: PL DDR4 calibration timeout; no DDR access attempted.\r\n");return;
    }
    xil_printf("  PASS: PL DDR4 calibration complete.\r\n");
    /* Four 1 GiB MMU blocks, normal write-back memory. DMA is noncoherent. */
    for(I=0;I<4U;I++) {
        xil_printf("  MMU map %lu/4 @ 0x%lx ...\r\n",(unsigned long)(I+1U),
                   (unsigned long)(PLR_BASE+I*0x40000000ULL));
        Xil_SetTlbAttributes((UINTPTR)(PLR_BASE+I*0x40000000ULL),NORM_WB_CACHE);
        xil_printf("  MMU map complete.\r\n");
    }
    if(!plr_bank_probe()) return;
    xil_printf("  Capacity=%lu frames, storage=%lu / 4294967296 bytes incl. guards.\r\n",
               (unsigned long)N,(unsigned long)(N*BURST_STRIDE));
    xil_printf("  Preparing PL DDR; previous rolling contents will be replaced.\r\n");
    for(F=0;F<N;F++) {
        u32 *P=(u32*)(UINTPTR)(PLR_BASE+F*BURST_STRIDE);
        for(I=0;I<16U;I++){P[I]=0xA55A1234U;P[16U+CAP_NBYTES/4U+I]=0x5AA54321U;}
        for(I=0;I<CAP_NBYTES/4U;I++) P[16U+I]=0xFFFFFFFFU;
        Xil_DCacheFlushRange((INTPTR)P,(u32)BURST_STRIDE);
        if((F+1U)%8U==0U||F+1U==N) xil_printf("  Prepared %lu/%lu\r\n",(unsigned long)(F+1U),(unsigned long)N);
    }
    OldExp=gmax_emu_read(GMAX_EMU_EXPOSURE);OldBlank=gmax_emu_read(GMAX_EMU_BLANKING);OldSeed=gmax_emu_read(GMAX_EMU_SEED);
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"PL ring stop")!=XST_SUCCESS) goto cleanup;
    gmax_emu_write(GMAX_EMU_COMMAND,1U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,1U,1U,"PL ring init")!=XST_SUCCESS) goto cleanup;
    gmax_emu_write(GMAX_EMU_EXPOSURE,120000U);gmax_emu_write(GMAX_EMU_BLANKING,1024U);
    gmax_emu_write(GMAX_EMU_COMMAND,2U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,3U,3U,"PL ring arm")!=XST_SUCCESS) goto cleanup;
    Frames=gmax_emu_read(GMAX_EMU_FRAMES);Errors=gmax_emu_read(GMAX_EMU_ERRORS);
    Accepted=gmax_emu_read(GMAX_EMU_ACCEPTED);Rejected=gmax_emu_read(GMAX_EMU_REJECTED);
    Target=Mode?0U:2U*N+3U;
    plr_command(1,N);plr_command(4,Target);
    if(plr_diag(4)||plr_diag(2)!=N||plr_diag(15)!=Target) goto fail;
    Started=capture_us();plr_command(2,0);
    xil_printf("  Capturing autonomously; oldest frame overwritten on wrap. ESC requests frame-boundary stop.\r\n");
    if(Target) xil_printf("  Qualification target=%lu completed frames.\r\n",(unsigned long)Target);
    do {
        S=plr_diag(1);
        if(!StopSent&&XUartPs_IsReceiveData(STDIN_BASEADDRESS)&&inbyte()==27){plr_command(3,0);StopSent=1;Started=capture_us();}
        if((!Mode||StopSent)&&capture_us()-Started>30000000ULL) {
            plr_command(3,0);
            xil_printf("  FAIL: scheduler timeout; awaiting ownership release.\r\n");
            while(plr_diag(1)&1U) usleep(1000U);
            goto fail;
        }
        usleep(1000U);
    } while(S&1U);
    Total=plr_diag(3);Retained=plr_diag(13);First=Total-Retained;
    if((S&7U)!=2U||!Total||plr_diag(4)||Retained!=(Total<N?Total:N)||
       (!Mode&&!StopSent&&Total!=Target)||gmax_emu_read(GMAX_EMU_FRAMES)-Frames!=Total||
       gmax_emu_read(GMAX_EMU_ERRORS)!=Errors||gmax_emu_read(GMAX_EMU_ACCEPTED)-Accepted!=Total||
       gmax_emu_read(GMAX_EMU_REJECTED)!=Rejected) goto fail;
    xil_printf("  Capture stopped: completed=%lu retained=%lu first-sequence=%lu cycles(mod 2^32)=%lu.\r\n",
               (unsigned long)Total,(unsigned long)Retained,(unsigned long)First,(unsigned long)plr_diag(5));
    for(F=First;F<Total;F++) {
        u32 Slot=F%N;u32 *P=(u32*)(UINTPTR)(PLR_BASE+Slot*BURST_STRIDE);u16 *Pixels=(u16*)(P+16U);
        Seed=(7U+37U*F)&1023U;Sum=0;
        Xil_DCacheInvalidateRange((INTPTR)P,(u32)BURST_STRIDE);
        for(I=0;I<16U;I++) if(P[I]!=0xA55A1234U||P[16U+CAP_NBYTES/4U+I]!=0x5AA54321U) {
            xil_printf("  Guard mismatch sequence=%lu slot=%lu word=%lu head=0x%08lx tail=0x%08lx\r\n",
              (unsigned long)F,(unsigned long)Slot,(unsigned long)I,(unsigned long)P[I],(unsigned long)P[16U+CAP_NBYTES/4U+I]);goto fail;
        }
        for(I=0;I<CAP_NPIX;I++) {
            u32 Expected=((I%4096U)+(I/4096U)+Seed)&1023U;
            if(Pixels[I]!=Expected) {
                xil_printf("  FAIL: seq=%lu slot=%lu pixel=%lu got=%lu expected=%lu\r\n",
                  (unsigned long)F,(unsigned long)Slot,(unsigned long)I,(unsigned long)Pixels[I],(unsigned long)Expected);goto fail;
            }
            Sum+=Pixels[I];
        }
        if(Sum!=0x7FA00000U) goto fail;
        xil_printf("  Retained %lu/%lu PASS: sequence=%lu slot=%lu pixels/guards/checksum address=0x%lx\r\n",
           (unsigned long)(F-First+1U),(unsigned long)Retained,(unsigned long)F,(unsigned long)Slot,(unsigned long)(UINTPTR)Pixels);
    }
    if(!Mode&&StopSent&&Total<Target)
        xil_printf("  STOPPED EARLY: retained pixels verified; two-wrap qualification incomplete.\r\n");
    else xil_printf("  PASS: PL DDR4 rolling capture, chronological retention and full pixel verification.\r\n");
    goto cleanup;
fail:
    xil_printf("  FAIL: PL ring status=0x%08lx error=%lu completed=%lu DMA=0x%08lx CAP=0x%08lx\r\n",
       (unsigned long)plr_diag(1),(unsigned long)plr_diag(4),(unsigned long)plr_diag(3),(unsigned long)plr_diag(6),(unsigned long)plr_diag(7));
    xil_printf("  Source deltas: frames=%lu accepted=%lu rejected=%lu checker-errors=%lu\r\n",
       (unsigned long)(gmax_emu_read(GMAX_EMU_FRAMES)-Frames),(unsigned long)(gmax_emu_read(GMAX_EMU_ACCEPTED)-Accepted),
       (unsigned long)(gmax_emu_read(GMAX_EMU_REJECTED)-Rejected),(unsigned long)(gmax_emu_read(GMAX_EMU_ERRORS)-Errors));
cleanup:
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    gmax_emu_write(GMAX_EMU_EXPOSURE,OldExp);gmax_emu_write(GMAX_EMU_BLANKING,OldBlank);gmax_emu_write(GMAX_EMU_SEED,OldSeed);
}
