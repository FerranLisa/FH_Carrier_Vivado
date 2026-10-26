"""Run through Vitis 2025.2: vitis -s scripts/update_vitis_v24.py.
The PowerShell preparation script supplies paths and creates backups first.
"""
import os
from pathlib import Path
import vitis
import platform_pb2
import build_pb2

workspace=Path(os.environ['GMAX_V24_WORKSPACE'])
xsa=Path(os.environ['GMAX_V24_XSA'])
client=vitis.create_client()
try:
    client.set_workspace(str(workspace))
    platform=client.get_component(name='FH_Carrier_platform')
    platform.update_hw(hw_design=str(xsa))
    if platform.build()!=platform_pb2.PlatformResponse.SUCCESS:
        raise RuntimeError('Platform build failed; inspect Vitis build log')
    p=workspace/'FH_Carrier_platform'
    local=p/'zynqmp_fsbl/psu_init.c'
    generated=p/'zynqmp_fsbl/zynqmp_fsbl_bsp/hw_artifacts/psu_init.c'
    if local.read_bytes()!=generated.read_bytes():
        raise RuntimeError('FSBL psu_init.c differs from regenerated handoff; reconcile before launch')
    params=(p/'export/FH_Carrier_platform/sw/standalone_psu_cortexa53_0/include/xparameters.h').read_text()
    import re
    if not re.search(r'XPAR_GMAX_CAPTURE_DMA_ADDRWIDTH\s+(?:0x40|64)\b',params):
        raise RuntimeError('Regenerated BSP does not describe the 64-bit DMA')
    if not re.search(r'XPAR_GMAX_PL_RING_CTRL_BASEADDR\s+0xa0070000',params,re.I):
        raise RuntimeError('Scheduler control missing from regenerated BSP')
    if client.get_component(name='FH_Carrier_Test').build()!=build_pb2.BuildResponse.SUCCESS:
        raise RuntimeError('Application build failed; inspect Vitis build log')
    print('VITIS_V24_UPDATE_PASS')
finally:
    vitis.dispose()
