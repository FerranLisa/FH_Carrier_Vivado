/* Executes the production ring implementation with deterministic MMIO mocks.
 * Cache operations are observed but not emulated; board testing is still needed.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>
#ifdef _MSC_VER
/* GNU alignment is checked separately in the linked A53 ELF. */
#define __attribute__(x)
#endif
typedef uint32_t u32;typedef uint16_t u16;typedef uint64_t u64;
typedef uintptr_t UINTPTR;typedef intptr_t INTPTR;
#define CAP_NPIX 12582912U
#define CAP_NBYTES (CAP_NPIX*2U)
#define CAP_GPIO 0xA0040000U
#define CAP_DMA 0xA0050000U
#define GMAX_EMU_COMMAND 4U
#define GMAX_EMU_STATUS 8U
#define GMAX_EMU_EXPOSURE 12U
#define GMAX_EMU_BLANKING 16U
#define GMAX_EMU_SEED 20U
#define GMAX_EMU_ACCEPTED 32U
#define GMAX_EMU_REJECTED 36U
#define GMAX_EMU_FRAMES 40U
#define GMAX_EMU_ERRORS 44U
#define XST_SUCCESS 0
static void cap_write(UINTPTR,u32),gmax_emu_write(u32,u32);
static u32 cap_read(UINTPTR),cap_diag(u32,u32),gmax_emu_read(u32);
static int cap_dma_reset(void),gmax_emu_wait(u32,u32,u32,const char*),capture_run(u32,u32,u32,int);
static u64 capture_us(void);
static void Xil_DCacheInvalidateRange(INTPTR,u32),Xil_DCacheFlushRange(INTPTR,u32);
static void usleep(u32 n){(void)n;}
static int xil_printf(const char *f,...){(void)f;return 0;}
#include "../software/gmax3412_ring.inc"

static u32 regs[32],dest,length,enabled,pending,done,fault,writes;
static u64 clock_us;
static void complete(void){
    pending=0;done=1;++regs[GMAX_EMU_FRAMES/4];++regs[0x44/4];
    regs[GMAX_EMU_STATUS/4]=19U;
}
static void cap_write(UINTPTR a,u32 v){
    if(a==CAP_GPIO){enabled=v&1U;return;}
    if(a==CAP_DMA+0x48U) dest=v;
    if(a==CAP_DMA+0x58U){assert(!pending);length=v;done=0;++writes;}
}
static u32 cap_read(UINTPTR a){
    if(a==CAP_DMA+0x58U) return length;
    assert(a==CAP_DMA+0x34U);
    if(fault==2U) return 0x10U;
    if(pending && fault!=4U && --pending==0) complete();
    return done?0x1002U:0U;
}
static u32 cap_diag(u32 e,u32 i){
    (void)e;
    if(i==2U) return done?CAP_NBYTES:0U;
    assert(i==0U);return done?0x46U:(enabled?1U:0U);
}
static void gmax_emu_write(u32 a,u32 v){
    if(a!=GMAX_EMU_COMMAND){regs[a/4]=v;return;}
    if(v==4U){regs[GMAX_EMU_STATUS/4]&=~2U;return;}
    if(v==2U){regs[GMAX_EMU_STATUS/4]|=3U;return;}
    assert(v==8U);assert(!pending);assert(Ring.active>=0);
    u32 s=(u32)Ring.active;
    assert(RingMeta[s].owner==RING_DMA);
    assert(dest==(u32)(uintptr_t)RingImage[s].pixels);
    assert(length==CAP_NBYTES);
    ++regs[GMAX_EMU_ACCEPTED/4];regs[GMAX_EMU_STATUS/4]=7U;pending=4U;
    for(u32 i=0;i<CAP_NPIX;++i) RingImage[s].pixels[i]=(u16)(((i&4095U)+(i>>12)+regs[GMAX_EMU_SEED/4])&1023U);
    if(fault==1U) RingImage[s].pixels[12345]^=1U;
    if(fault==3U) RingImage[s].after[0]^=1U;
    if(fault==6U) ++RingMeta[s].sequence;
    if(fault==7U) ++regs[GMAX_EMU_REJECTED/4];
}
static u32 gmax_emu_read(u32 a){
    if(a==0x48U) return regs[GMAX_EMU_EXPOSURE/4];
    if(a==0x4CU || a==0x50U) return fault==5U?255U:256U;
    if(a==0x54U || a==0x58U) return regs[GMAX_EMU_BLANKING/4];
    if(a==0x5CU) return 3072U*256U+3071U*regs[GMAX_EMU_BLANKING/4];
    if(a==0x60U) return 3072U;
    return regs[a/4];
}
static int cap_dma_reset(void){pending=0;done=0;return 0;}
static int gmax_emu_wait(u32 a,u32 m,u32 e,const char *s){
    (void)s;if(pending){complete();regs[GMAX_EMU_STATUS/4]&=~2U;}
    return (gmax_emu_read(a)&m)==e?0:1;
}
static int capture_run(u32 a,u32 b,u32 c,int d){(void)a;(void)b;(void)c;(void)d;return 1;}
static u64 capture_us(void){clock_us+=100U;return clock_us;}
static void Xil_DCacheInvalidateRange(INTPTR a,u32 n){
    assert((n&63)==0);
    for(u32 s=0;s<RING_SLOTS;++s) if((uintptr_t)a>=(uintptr_t)&RingImage[s] && (uintptr_t)a<(uintptr_t)(&RingImage[s]+1))
        assert(RingMeta[s].owner==RING_VERIFY);
}
static void Xil_DCacheFlushRange(INTPTR a,u32 n){(void)a;assert((n&63)==0);}
static void reset_mock(u32 f){memset(regs,0,sizeof(regs));fault=f;pending=done=writes=0;clock_us=0;}
int main(void){
    (void)test_gmax3412_ring;
    reset_mock(0);assert(ring_phase(12,1024,0,0));
    assert(Ring.highwater==4 && Ring.pauses>0 && Ring.overlap>0 && writes==12);
    reset_mock(0);assert(ring_phase(5,1024,12,1));
    assert(Ring.overruns==1 && writes==4 && Ring.consumed==4);
    reset_mock(0);assert(ring_phase(8,512,16,0));assert(writes==8);
    for(u32 f=1;f<=7;++f){reset_mock(f);assert(!ring_phase(8,512,100,0));assert(pending==0 && enabled==0);}
    reset_mock(0);assert(ring_phase(8,1024,24,0));
    puts("RING_HOST_TEST_PASS: wrap, backpressure, overlap, protected overrun, recovery, pixel/guard/DMA/timeout/timing/order/trigger faults");
    return 0;
}
