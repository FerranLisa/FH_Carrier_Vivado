/* v22: cooperative producer/consumer pipeline. No interrupts or SG DMA needed.
 * DMA writes one owned slot while CPU verifies another in 4096-pixel slices.
 * Source is trigger controlled: ring-full either pauses triggers or stops with
 * a reported overrun. It never overwrites unread memory. Not gapless streaming.
 */
#define RING_SLOTS 4U
#define RING_SLICE 4096U
enum {RING_FREE,RING_DMA,RING_READY,RING_VERIFY};
static struct {
    u32 before[16];u16 pixels[CAP_NPIX];u32 after[16];
} RingImage[RING_SLOTS] __attribute__((aligned(64)));
static struct {
    u32 owner,sequence,seed,index,sum;
} RingMeta[RING_SLOTS];
static struct {
    u32 issued,completed,consumed,highwater,pauses,overruns,overlap;
    u32 frame_before,error_before,accept_before,reject_before,timing_before;
    u32 blocked,base,blank;
    int active;
    u64 started,last_completion,max_gap;
} Ring;

static int ring_issue(u32 Slot)
{
    u32 P;
    if(RingMeta[Slot].owner!=RING_FREE || Ring.issued-Ring.consumed>=RING_SLOTS) return 0;
    /* Reset the bridge FIFO between packets; DMA remains running and idle. */
    cap_write(CAP_GPIO,0U);usleep(100U);
    RingMeta[Slot].sequence=Ring.base+Ring.issued;
    RingMeta[Slot].seed=(7U+37U*RingMeta[Slot].sequence)&1023U;
    RingMeta[Slot].index=0U;RingMeta[Slot].sum=0U;
    gmax_emu_write(GMAX_EMU_SEED,RingMeta[Slot].seed);
    Ring.frame_before=gmax_emu_read(GMAX_EMU_FRAMES);
    Ring.error_before=gmax_emu_read(GMAX_EMU_ERRORS);
    Ring.accept_before=gmax_emu_read(GMAX_EMU_ACCEPTED);
    Ring.reject_before=gmax_emu_read(GMAX_EMU_REJECTED);
    Ring.timing_before=gmax_emu_read(0x44U);
    cap_write(CAP_DMA+0x34U,0x7000U);
    cap_write(CAP_DMA+0x30U,1U);
    cap_write(CAP_DMA+0x48U,(u32)(UINTPTR)RingImage[Slot].pixels);
    cap_write(CAP_DMA+0x58U,CAP_NBYTES);
    cap_write(CAP_GPIO,1U);
    for(P=0U;P<1000U;++P) {if(cap_diag(1U,0U)&1U) break;usleep(10U);}
    if(P==1000U) {xil_printf("  FAIL: ring arm timeout.\r\n");return 0;}
    RingMeta[Slot].owner=RING_DMA;Ring.active=(int)Slot;
    Ring.started=capture_us();
    if(Ring.issued && Ring.started-Ring.last_completion>Ring.max_gap)
        Ring.max_gap=Ring.started-Ring.last_completion;
    ++Ring.issued;
    if(Ring.issued-Ring.consumed>Ring.highwater) Ring.highwater=Ring.issued-Ring.consumed;
    gmax_emu_write(GMAX_EMU_COMMAND,8U);
    return 1;
}
static int ring_poll(void)
{
    u32 D,C,S;
    if(Ring.active<0) return 1;
    S=(u32)Ring.active;
    if(RingMeta[S].owner!=RING_DMA) return 0;
    D=cap_read(CAP_DMA+0x34U);C=cap_diag(1U,0U);
    if((D&0x770U)||(C&0x38U)) {
        xil_printf("  FAIL: ring DMA=0x%08lX capture=0x%08lX seq=%lu\r\n",
                   (unsigned long)D,(unsigned long)C,(unsigned long)RingMeta[S].sequence);return 0;
    }
    if((D&0x1002U)==0x1002U && (C&0x44U)==0x44U &&
       gmax_emu_read(GMAX_EMU_FRAMES)==Ring.frame_before+1U) {
        if(cap_diag(1U,2U)!=CAP_NBYTES || cap_read(CAP_DMA+0x58U)!=CAP_NBYTES ||
           gmax_emu_read(GMAX_EMU_ERRORS)!=Ring.error_before ||
           gmax_emu_read(GMAX_EMU_ACCEPTED)!=Ring.accept_before+1U ||
           gmax_emu_read(GMAX_EMU_REJECTED)!=Ring.reject_before ||
           !(gmax_emu_read(GMAX_EMU_STATUS)&16U) ||
           gmax_emu_read(0x44U)!=Ring.timing_before+1U ||
           gmax_emu_read(0x48U)!=120000U || gmax_emu_read(0x4CU)!=256U ||
           gmax_emu_read(0x50U)!=256U || gmax_emu_read(0x54U)!=Ring.blank ||
           gmax_emu_read(0x58U)!=Ring.blank || gmax_emu_read(0x60U)!=3072U ||
           gmax_emu_read(0x5CU)!=3072U*256U+3071U*Ring.blank) {
            xil_printf("  FAIL: ring completion metadata/timing.\r\n");return 0;
        }
        Ring.last_completion=capture_us();
        RingMeta[S].owner=RING_READY;++Ring.completed;Ring.active=-1;
        return 1;
    }
    if(capture_us()-Ring.started>2000000ULL) {
        xil_printf("  FAIL: ring capture timeout DMA=%08lX CAP=%08lX\r\n",(unsigned long)D,(unsigned long)C);return 0;
    }
    return 1;
}
static int ring_consume(void)
{
    u32 S=Ring.consumed%RING_SLOTS,I,End,Value,Expected;
    if(RingMeta[S].owner==RING_READY) {
        if(RingMeta[S].sequence!=Ring.base+Ring.consumed) {
            xil_printf("  FAIL: ring frame order.\r\n");return 0;
        }
        RingMeta[S].owner=RING_VERIFY;
    }
    if(RingMeta[S].owner!=RING_VERIFY) return 1;
    if(Ring.active>=0) ++Ring.overlap;
    I=RingMeta[S].index;End=I+RING_SLICE;
    if(End>CAP_NPIX) End=CAP_NPIX;
    /* Aligned payload slices; never invalidate CPU-owned metadata/dirty lines. */
    Xil_DCacheInvalidateRange((INTPTR)&RingImage[S].pixels[I],(End-I)*2U);
    for(;I<End;++I) {
        Value=RingImage[S].pixels[I];Expected=((I&4095U)+(I>>12)+RingMeta[S].seed)&1023U;
        if(Value!=Expected) {
            xil_printf("  FAIL: ring seq=%lu pixel=%lu got=%lu expected=%lu\r\n",
                       (unsigned long)RingMeta[S].sequence,(unsigned long)I,(unsigned long)Value,(unsigned long)Expected);return 0;
        }
        RingMeta[S].sum+=Value;
    }
    RingMeta[S].index=End;
    if(End==CAP_NPIX) {
        Xil_DCacheInvalidateRange((INTPTR)RingImage[S].before,64U);
        Xil_DCacheInvalidateRange((INTPTR)RingImage[S].after,64U);
        for(I=0;I<16U;++I) if(RingImage[S].before[I]!=0xA55A1234U || RingImage[S].after[I]!=0x5AA54321U) {
            xil_printf("  FAIL: ring guard region.\r\n");return 0;
        }
        if(RingMeta[S].sum!=0x7FA00000U) {xil_printf("  FAIL: ring checksum.\r\n");return 0;}
        RingMeta[S].owner=RING_FREE;++Ring.consumed;
    }
    return 1;
}
static int ring_phase(u32 Count,u32 Blank,u32 Base,int ForceOverrun)
{
    u32 S,I,Slot,Expected;int Pass=0,Stopped=0;u64 Progress;
    memset(&Ring,0,sizeof(Ring));memset(RingMeta,0,sizeof(RingMeta));
    Ring.active=-1;Ring.base=Base;Ring.blank=Blank;
    xil_printf("  Ring phase: requested=%lu blank=%lu first-sequence=%lu forced-overrun=%u\r\n",
               (unsigned long)Count,(unsigned long)Blank,(unsigned long)Base,(unsigned int)ForceOverrun);
    cap_write(CAP_GPIO,4U);usleep(1000U);cap_write(CAP_GPIO,0U);
    if(cap_dma_reset()!=XST_SUCCESS) goto done;
    for(S=0;S<RING_SLOTS;++S) {
        UINTPTR A=(UINTPTR)&RingImage[S];
        if(A>=0x80000000ULL || sizeof(RingImage[S])>0x80000000ULL-A) {
            xil_printf("  FAIL: ring buffer outside low DDR.\r\n");goto done;
        }
        for(I=0;I<16U;++I) {RingImage[S].before[I]=0xA55A1234U;RingImage[S].after[I]=0x5AA54321U;}
        for(I=0;I<CAP_NPIX;++I) RingImage[S].pixels[I]=0xFFFFU;
        Xil_DCacheFlushRange((INTPTR)&RingImage[S],sizeof(RingImage[S]));
    }
    gmax_emu_write(GMAX_EMU_EXPOSURE,120000U);gmax_emu_write(GMAX_EMU_BLANKING,Blank);
    gmax_emu_write(GMAX_EMU_COMMAND,2U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,3U,3U,"ring start")!=XST_SUCCESS) goto done;
    Progress=capture_us();
    while(1) {
        u32 OldConsumed=Ring.consumed;
        if(!ring_poll()) goto done;
        if(!Stopped && Ring.issued<Count && Ring.active<0) {
            Slot=Ring.issued%RING_SLOTS;
            if(RingMeta[Slot].owner==RING_FREE) {
                Ring.blocked=0;
                if(!ring_issue(Slot)) goto done;
            } else {
                if(!Ring.blocked) ++Ring.pauses;
                Ring.blocked=1;
                if(ForceOverrun) {
                    ++Ring.overruns;Stopped=1;
                    xil_printf("  EXPECTED OVERRUN: next request refused; all unread slots retained.\r\n");
                }
            }
        }
        /* Fault phase intentionally withholds consumption until ring exhaustion. */
        if(!ForceOverrun || Stopped) {if(!ring_consume()) goto done;}
        if(Ring.consumed!=OldConsumed) {
            Progress=capture_us();
            if((Ring.consumed&7U)==0U)
                xil_printf("  Ring progress: verified=%lu issued=%lu last-sequence=%lu high-water=%lu\r\n",
                    (unsigned long)Ring.consumed,(unsigned long)Ring.issued,
                    (unsigned long)(Ring.base+Ring.consumed-1U),(unsigned long)Ring.highwater);
        }
        if(capture_us()-Progress>30000000ULL) {xil_printf("  FAIL: ring progress timeout.\r\n");goto done;}
        if((Stopped || Ring.issued==Count) && Ring.active<0 && Ring.consumed==Ring.completed) break;
    }
    Expected=ForceOverrun ? RING_SLOTS:Count;
    Pass=Ring.issued==Expected && Ring.completed==Expected && Ring.consumed==Expected &&
         Ring.overruns==(ForceOverrun?1U:0U) && Ring.highwater<=RING_SLOTS &&
         (ForceOverrun || Ring.overlap!=0U);
    for(S=0;S<RING_SLOTS;++S) if(RingMeta[S].owner!=RING_FREE) Pass=0;
done:
    gmax_emu_write(GMAX_EMU_COMMAND,4U);
    if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"ring drain")!=XST_SUCCESS) Pass=0;
    cap_write(CAP_GPIO,4U);usleep(1000U);
    if(cap_dma_reset()!=XST_SUCCESS) Pass=0;
    cap_write(CAP_GPIO,0U);
    xil_printf("  %s: issued=%lu complete=%lu verified=%lu high-water=%lu pauses=%lu overruns=%lu overlap-slices=%lu max-rearm-gap-us=%lu\r\n",
        Pass?"PASS":"FAIL",(unsigned long)Ring.issued,(unsigned long)Ring.completed,(unsigned long)Ring.consumed,
        (unsigned long)Ring.highwater,(unsigned long)Ring.pauses,(unsigned long)Ring.overruns,
        (unsigned long)Ring.overlap,(unsigned long)Ring.max_gap);
    return Pass;
}
static void test_gmax3412_ring(void)
{
    u32 E,B,S;int Pass=0;
    xil_printf("\r\nGMAX3412 DDR RING v22: four buffers, pipelined capture/verification\r\n");
    /* Existing baseline verifies identities, initialization and timing capability. */
    if(!capture_run(1U,1024U,120000U,2)) return;
    E=gmax_emu_read(GMAX_EMU_EXPOSURE);B=gmax_emu_read(GMAX_EMU_BLANKING);S=gmax_emu_read(GMAX_EMU_SEED);
    if(!ring_phase(64U,1024U,0U,0)) goto done;
    if(!ring_phase(64U,512U,64U,0)) goto done;
    if(!ring_phase(RING_SLOTS+1U,1024U,128U,1)) goto done;
    if(!ring_phase(8U,1024U,132U,0)) goto done;
    Pass=1;
done:
    gmax_emu_write(GMAX_EMU_EXPOSURE,E);gmax_emu_write(GMAX_EMU_BLANKING,B);gmax_emu_write(GMAX_EMU_SEED,S);
    xil_printf("  %s: DDR ring ordering, ownership, overrun protection and recovery.\r\n",Pass?"PASS":"FAIL");
    xil_printf("  Trigger-paced acquisition with software rearm gaps; not autonomous/gapless streaming.\r\n");
}
