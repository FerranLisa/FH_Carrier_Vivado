# Restore completed batch-build artifacts into the GUI's run directories.
# Never marks an unbuilt design successful: verifies exports, original build
# evidence, both checkpoints and regenerated reports before run registration.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
if(Get-Process vivado -ErrorAction SilentlyContinue){throw 'Close Vivado before synchronizing project run results.'}
& "$PSScriptRoot/verify_gmax3412_pl_ddr_export.ps1"
$log=Get-Content results/pl_ddr_build.log -Raw
foreach($proof in @('Synthesis finished with 0 errors','Bitgen Completed Successfully','PL_DDR_RESET_FIX: active-low auxiliary input connected to constant one')) {
    if(!$log.Contains($proof)){throw "Original build evidence missing: $proof"}
}
$stem=Join-Path $root 'exports/gmax3412_pl_ddr/FH_Carrier_Bringup_GMAX3412_PL_DDR'
$syn=Join-Path $root 'FH_Carrier_Bringup.runs/synth_1'
$impl=Join-Path $root 'FH_Carrier_Bringup.runs/impl_1'
$backup=Join-Path $root ('results/gui_run_backup_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item FH_Carrier_Bringup.xpr $backup
Copy-Item -LiteralPath $syn,$impl -Destination $backup -Recurse
Write-Host "Previous GUI run files preserved in $backup"
$vivado='C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat'
& $vivado -mode batch -source scripts/report_v24_gui_checkpoints.tcl -log results/v24_gui_reports.log -journal results/v24_gui_reports.jou
if($LASTEXITCODE -ne 0){throw 'Checkpoint/report validation failed; run states unchanged'}
if(!(Select-String results/v24_gui_reports.log -Pattern '^V24_GUI_CHECKPOINT_REPORTS_PASS:' -Quiet)){throw 'Checkpoint report success marker missing'}
$report=Get-Content (Join-Path $impl 'FH_Carrier_Bringup_top_route_status.rpt') -Raw
if($report -notmatch 'nets with routing errors\.+\s*:\s*0\s*:'){throw 'Imported checkpoint has routing errors'}
if((Get-Content (Join-Path $impl 'FH_Carrier_Bringup_top_bus_skew_routed.rpt') -Raw) -match 'VIOLATED'){throw 'Imported checkpoint bus skew failed'}
foreach($pair in @(
    @("${stem}_synth.dcp",(Join-Path $syn 'FH_Carrier_Bringup_top.dcp')),
    @("${stem}_routed.dcp",(Join-Path $impl 'FH_Carrier_Bringup_top_routed.dcp')),
    @("${stem}.bit",(Join-Path $impl 'FH_Carrier_Bringup_top.bit')),
    @("${stem}.ltx",(Join-Path $impl 'FH_Carrier_Bringup_top.ltx')))) {
    Copy-Item -LiteralPath $pair[0] -Destination $pair[1] -Force
    if((Get-FileHash $pair[0]).Hash -ne (Get-FileHash $pair[1]).Hash){throw 'Imported artifact hash mismatch'}
}
# Native run state files reflect the completed batch operations, not a new run.
# No intermediate opt/placed checkpoints exist: restart from synthesis to rebuild.
$journal=Get-Content results/pl_ddr_build.jou -Raw
if($journal -notmatch '# Process ID\s*:\s*(\d+)'){throw 'Original batch process ID missing'}
$batchProcess=$Matches[1]
$processXml='<?xml version="1.0"?><ProcessHandle Version="1" Minor="0"><Process Command="vivado.exe" Owner="'+[Security.SecurityElement]::Escape($env:USERNAME)+'" Host="'+[Security.SecurityElement]::Escape($env:COMPUTERNAME)+'" Pid="'+$batchProcess+'" /></ProcessHandle>'
foreach($dir in @($syn,$impl)) {
    foreach($name in @('.vivado.error.rst','.vivado.begin.rst','__synthesis_is_running__','.Vivado_Synthesis.queue.rst')) {
        $path=Join-Path $dir $name
        if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path}
    }
    Copy-Item results/pl_ddr_build.log (Join-Path $dir 'runme.log') -Force
    Set-Content (Join-Path $dir '.vivado.begin.rst') $processXml
    Set-Content (Join-Path $dir 'V24_IMPORTED_RESULTS.txt') 'Restored exact completed v24 batch results; original build log copied as runme.log. No new synthesis/routing/bitgen performed. Intermediate checkpoints are unavailable.'
    New-Item -ItemType File -Path (Join-Path $dir '.vivado.end.rst') -Force | Out-Null
}
# Replace the old failed GUI synthesis report with the successful batch stage.
# Keep the complete original log in results; XSA-export recovery is a separate
# operation and must not appear as a synthesis/implementation failure here.
$lines=Get-Content results/pl_ddr_build.log
$synthStart=($lines | Select-String '^Command: synth_design ' | Select-Object -First 1).LineNumber-1
$synthEnd=($lines | Select-String '^synth_design: Time ' | Select-Object -First 1).LineNumber-1
$implEnd=($lines | Select-String '^write_debug_probes: Time ' | Select-Object -First 1).LineNumber-1
if($synthStart -lt 0 -or $synthEnd -le $synthStart -or $implEnd -le $synthEnd){throw 'Cannot locate successful build stage logs'}
$lines[$synthStart..$synthEnd] | Set-Content (Join-Path $syn 'FH_Carrier_Bringup_top.vds')
$lines[$synthStart..$synthEnd] | Set-Content (Join-Path $syn 'runme.log')
$lines[($synthEnd+1)..$implEnd] | Set-Content (Join-Path $impl 'runme.log')
foreach($dir in @($syn,$impl)) {
    foreach($name in @('vivado.pb','vivado.jou')) {
        $path=Join-Path $dir $name
        if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path}
    }
}
New-Item -ItemType File -Path (Join-Path $syn '__synthesis_is_complete__') -Force | Out-Null
foreach($step in @('init_design','opt_design','place_design','phys_opt_design','route_design','write_bitstream')) {
    Set-Content (Join-Path $impl ".$step.begin.rst") $processXml
    New-Item -ItemType File -Path (Join-Path $impl ".$step.end.rst") -Force | Out-Null
}
& $vivado -mode batch -source scripts/register_v24_gui_runs.tcl -log results/v24_gui_register.log -journal results/v24_gui_register.jou
if($LASTEXITCODE -ne 0){throw 'GUI run registration failed; inspect results/v24_gui_register.log'}
if(!(Select-String results/v24_gui_register.log -Pattern '^V24_GUI_RUNS_PASS$' -Quiet)){throw 'GUI verification success marker missing'}
Write-Host 'V24_GUI_SYNC_PASS: reopen FH_Carrier_Bringup.xpr. Tested BIT unchanged.'
