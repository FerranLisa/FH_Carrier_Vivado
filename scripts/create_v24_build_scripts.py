from pathlib import Path
r=Path(__file__).resolve().parents[1]
for name in ['build_gmax3412_scheduler_export.tcl','finalize_gmax3412_scheduler_xsa.ps1','verify_gmax3412_scheduler_export.ps1']:
    s=(r/'scripts'/name).read_text().replace('exports gmax3412_scheduler','exports gmax3412_pl_ddr').replace('exports/gmax3412_scheduler','exports/gmax3412_pl_ddr').replace('FH_Carrier_Bringup_GMAX3412_Scheduler','FH_Carrier_Bringup_GMAX3412_PL_DDR').replace('finalize_gmax3412_scheduler','finalize_gmax3412_pl_ddr').replace('verify_gmax3412_scheduler_export','verify_gmax3412_pl_ddr_export')
    if name.startswith('build_'):
        s=s.replace('upgrade_ip [get_ips design_1_gmax_scheduler_0]', 'upgrade_ip [get_ips design_1_gmax_pl_ring_0]')
        s=s.replace('validate_bd_design','source [file join $root scripts exclude_pl_ddr_control_segments.tcl]\nvalidate_bd_design',1)
        s=s.replace('    write_checkpoint -force ${stem}_synth.dcp','    if {[llength [get_cells -hier -filter {NAME =~ *gmax_pl_ring* && REF_NAME =~ FD*}]] < 100} {error "PL ring absent"}\n    set_false_path -to [get_pins -hier -regexp {.*gmax_pl_ring.*/calibrated_reg\\[0\\]/D}]\n    write_checkpoint -force ${stem}_synth.dcp')
    else:
        if name.startswith('verify_'):
            s=s.replace("$foundEmulator = $true", """$pl=$dma.SelectSingleNode(".//MEMRANGE[@BASEVALUE='0x1000000000']")
            if(!$pl -or $pl.HIGHVALUE -ne '0x10FFFFFFFF'){throw 'DMA 4 GiB PL DDR aperture missing'}
            if($hwh -notmatch 'gmax_pl_ring' -or $hwh -notmatch 'A0070000' -or $hwh -notmatch 'pl_ddr4'){throw 'PL ring/MIG missing'}
            $foundEmulator = $true""")
    dest=name.replace('gmax3412_scheduler','gmax3412_pl_ddr')
    (r/'scripts'/dest).write_text(s)
for name in ['prepare_vitis_v23.ps1','update_vitis_v23.py']:
    s=(r/'scripts'/name).read_text().replace('v23','v24').replace('V23','V24').replace('gmax3412_scheduler','gmax3412_pl_ddr').replace('FH_Carrier_Bringup_GMAX3412_Scheduler','FH_Carrier_Bringup_GMAX3412_PL_DDR')
    if name.endswith('.py'):
        s=s.replace('XPAR_GMAX_SCHEDULER_CTRL_BASEADDR','XPAR_GMAX_PL_RING_CTRL_BASEADDR').replace('0xa0060000','0xa0070000')
    else:
        s=s.replace('verify_gmax3412_burst_elf.py','verify_gmax3412_pl_ring_elf.py').replace('followed by B (start with 4 frames)','followed by P (start with 4 frames, default qualification mode)')
    (r/'scripts'/name.replace('v23','v24')).write_text(s)
p=r/'scripts/build_bringup_v24.ps1';s=p.read_text().replace('BRINGUP_V23_BUILD_PASS','BRINGUP_V24_BUILD_PASS').replace('verify_gmax3412_burst_elf.py','verify_gmax3412_pl_ring_elf.py');p.write_text(s)
