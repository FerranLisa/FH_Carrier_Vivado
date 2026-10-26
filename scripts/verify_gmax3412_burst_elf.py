"""Check actual ELF placement and high-DDR MMU blocks, not just source constants."""
from pathlib import Path
import struct
import sys
r=Path(__file__).resolve().parents[1]
p=Path(sys.argv[1]) if len(sys.argv)>1 else r/'exports/gmax3412_scheduler/software/BringupTest_v23.elf'
b=p.read_bytes()
assert b'GMAX3412 AUTONOMOUS BURST v23' in b, 'Stale application: v23 burst test missing'
assert b[:6]==b'\x7fELF\x02\x01', 'Expected little-endian ELF64'
phoff,shoff=struct.unpack_from('<QQ',b,32)
phsize,phnum,shsize,shnum,shstr=struct.unpack_from('<HHHHH',b,54)
for i in range(phnum):
    typ,flags,off,va,pa,filesz,memsz,align=struct.unpack_from('<IIQQQQQQ',b,phoff+i*phsize)
    if typ==1:
        assert pa+memsz<=0x10000000, 'Load segment overlaps reserved capture memory'
headers=[struct.unpack_from('<IIQQQQIIQQ',b,shoff+i*shsize) for i in range(shnum)]
names=headers[shstr]; strings=b[names[4]:names[4]+names[5]]
sections={strings[h[0]:].split(b'\0',1)[0].decode():h for h in headers}
h=sections['.mmu_tbl1']; table=b[h[4]:h[4]+h[5]]
for i in (32,33):
    descriptor=struct.unpack_from('<Q',table,i*8)[0]
    assert descriptor&3==1, 'High DDR is not mapped as a block'
    assert descriptor&0x0000FFFFC0000000==i*0x40000000, 'High DDR is not identity-mapped'
    # ZynqMP standalone boot.S sets MAIR index 1 to 0xFF (normal WB).
    assert descriptor&0x1c==0x04, 'High DDR is not normal cacheable memory'
stride=4096*3072*2+2*64
assert 4*stride==100663808
assert 119*stride<=3000000000<120*stride
for n in range(119):
    base=0x10000000+n*stride if n<74 else 0x800000000+(n-74)*stride
    assert base%64==0
    assert (0x10000000<=base and base+stride<=0x7ff00000) or (0x800000000<=base and base+stride<=0x880000000)
print(f'BURST_ELF_PASS: {p.name}; app below 256 MiB, high DDR mapped/cacheable; 4..119 guarded frames, max {119*stride} bytes')
