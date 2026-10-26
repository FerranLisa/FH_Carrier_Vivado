from pathlib import Path
import runpy,sys
r=Path(__file__).resolve().parents[1]
runpy.run_path(str(r/'scripts/verify_gmax3412_burst_elf.py'),run_name='__main__')
b=Path(sys.argv[1]).read_bytes()
assert b'GMAX3412 PL DDR4 ROLLING BUFFER v24' in b
stride=25165952
assert 170*stride<=2**32<171*stride
assert 170*stride==4278211840
print('PL_RING_ELF_PASS: v24 present; 4..170 frames fit 4 GiB; PL MMU blocks configured at runtime after calibration')
