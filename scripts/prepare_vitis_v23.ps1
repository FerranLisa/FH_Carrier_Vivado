param([string]$Workspace='C:\Projects\VITIS\FH_Carrier_Bringup',[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$platform=Join-Path $Workspace 'FH_Carrier_platform'
$app=Join-Path $Workspace 'FH_Carrier_Test'
$source=Join-Path $root 'exports/gmax3412_scheduler/software/BringupTest_v23.c'
$bit=Join-Path $root 'exports/gmax3412_scheduler/FH_Carrier_Bringup_GMAX3412_Scheduler.bit'
$xsa=Join-Path $root 'exports/gmax3412_scheduler/FH_Carrier_Bringup_GMAX3412_Scheduler.xsa'
$launch=Join-Path $app '_ide/launch.json'
$target=Join-Path $app 'src/BringupTest.c'
$ninja='C:\AMDDesignTools\2025.2\Vitis\bin\ninja.exe'
$toolchainBin='C:\AMDDesignTools\2025.2\Vitis\gnu\aarch64\nt\aarch64-none\bin'
$sizeTool=Join-Path $toolchainBin 'aarch64-none-elf-size.exe'
foreach($p in @($source,$bit,$xsa,$launch,$target,$ninja,$sizeTool,(Join-Path $root 'exports/gmax3412_scheduler/software/lscript_v23.ld'),(Join-Path $PSScriptRoot 'update_vitis_v23.py'))) {
    if(!(Test-Path -LiteralPath $p)){throw "Missing required file: $p"}
}
$platformXsas=@(Get-ChildItem -LiteralPath (Join-Path $platform 'export/FH_Carrier_platform/hw') -Filter '*.xsa')
if($platformXsas.Count -ne 1) {
    $component=Get-Content -LiteralPath (Join-Path $platform 'vitis-comp.json') -Raw | ConvertFrom-Json
    $currentName=Split-Path -Leaf $component.configuration.xsaPathInPlatform
    $platformXsas=@($platformXsas | Where-Object {$_.Name -eq $currentName})
}
if($platformXsas.Count -ne 1){throw 'Cannot identify the currently selected exported platform XSA.'}
$platformXsa=$platformXsas[0].FullName
# v23 changes PL addressing. Require unchanged PS init before platform regeneration.
# Permit the proven capture BSP only when its PS initialization matches exactly.
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-XsaEntryHash([string]$Path,[string]$Name) {
    $archive=[IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry=$archive.GetEntry($Name)
        if(!$entry){throw "Missing $Name in $Path"}
        $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
        try {return [BitConverter]::ToString($sha.ComputeHash($stream))}
        finally {$stream.Dispose();$sha.Dispose()}
    } finally {$archive.Dispose()}
}
foreach($name in @('psu_init.c','psu_init.h','psu_init.tcl')) {
    if((Get-XsaEntryHash $platformXsa $name) -ne (Get-XsaEntryHash $xsa $name)) {
        throw "Platform PS initialization differs ($name). Update platform from Scheduler XSA and rebuild first."
    }
}
$params=Get-Content -LiteralPath (Join-Path $platform 'export/FH_Carrier_platform/sw/standalone_psu_cortexa53_0/include/xparameters.h') -Raw
if($params -notmatch '(?i)XPAR_GMAX_CAPTURE_CTRL_BASEADDR\s+0xa0040000' -or $params -notmatch '(?i)XPAR_GMAX_CAPTURE_DMA_BASEADDR\s+0xa0050000') {throw 'Capture peripherals missing from BSP.'}
& (Join-Path $PSScriptRoot 'verify_gmax3412_scheduler_export.ps1')
$fsblSource=Join-Path $platform 'zynqmp_fsbl/psu_init.c'
$generated=Join-Path $platform 'zynqmp_fsbl/zynqmp_fsbl_bsp/hw_artifacts/psu_init.c'
if((Get-FileHash $fsblSource).Hash -ne (Get-FileHash $generated).Hash){throw 'FSBL initialization source differs from current generated hardware. Reconcile before continuing.'}
$config=Get-Content -LiteralPath $launch -Raw | ConvertFrom-Json
$matches=@($config.configurations | Where-Object {$_.name -eq 'FH_Carrier_Test_app_hw_1'})
if($matches.Count -ne 1){throw 'Expected one FH_Carrier_Test_app_hw_1 launch configuration.'}
if($ValidateOnly) {Write-Host 'PASS: v23 preparation prerequisites validated; Vitis files unchanged.';return}
$workspacePath=(Resolve-Path -LiteralPath $Workspace).Path.TrimEnd('\','/')
# A complete platform backup contains vitis-comp.json. Keep it outside the
# workspace so Vitis cannot discover a second component with the same name.
$backupRoot=Join-Path (Split-Path $workspacePath -Parent) ((Split-Path $workspacePath -Leaf)+'_backups')
$backup=Join-Path $backupRoot ('v23_backup_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'BringupTest.c')
Copy-Item -LiteralPath $launch -Destination (Join-Path $backup 'launch.json')
Copy-Item -LiteralPath $platform -Destination (Join-Path $backup 'FH_Carrier_platform') -Recurse
Copy-Item -LiteralPath (Join-Path $app 'src/lscript.ld') -Destination (Join-Path $backup 'lscript.ld')
Copy-Item -LiteralPath $source -Destination $target
Copy-Item -LiteralPath (Join-Path $root 'exports/gmax3412_scheduler/software/lscript_v23.ld') -Destination (Join-Path $app 'src/lscript.ld')
$matches[0].targetSetup.bitstreamFile=$bit
$matches[0].targetSetup.programDevice=$true
$matches[0].targetSetup.resetSystem=$true
$config | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $launch -Encoding UTF8
$previousPath=$env:PATH
$previousWorkspace=$env:GMAX_V23_WORKSPACE
$previousXsa=$env:GMAX_V23_XSA
try {
    # Generated Ninja post-link commands invoke size by name, unlike gcc.
    # Supply the Vitis toolchain to child processes without changing system PATH.
    $env:PATH=$toolchainBin+';'+$previousPath
    $env:GMAX_V23_WORKSPACE=$Workspace
    $env:GMAX_V23_XSA=$xsa
    & 'C:/AMDDesignTools/2025.2/Vitis/bin/vitis.bat' -s (Join-Path $PSScriptRoot 'update_vitis_v23.py') | Tee-Object -FilePath (Join-Path $backup 'vitis_update.log')
    if($LASTEXITCODE -ne 0){throw "Application build failed. Backups: $backup"}
    if(!(Select-String -LiteralPath (Join-Path $backup 'vitis_update.log') -Pattern '^VITIS_V23_UPDATE_PASS$' -Quiet)){throw "Vitis update did not report success. Backups: $backup"}
} finally {
    $env:PATH=$previousPath
    $env:GMAX_V23_WORKSPACE=$previousWorkspace
    $env:GMAX_V23_XSA=$previousXsa
}
if((Get-FileHash $source).Hash -ne (Get-FileHash $target).Hash){throw 'Installed source verification failed.'}
if((Get-FileHash (Join-Path $root 'exports/gmax3412_scheduler/software/lscript_v23.ld')).Hash -ne (Get-FileHash (Join-Path $app 'src/lscript.ld')).Hash){throw 'Installed linker reservation verification failed.'}
& 'C:/AMDDesignTools/2025.2/tps/win64/python-3.13.0/python.exe' (Join-Path $PSScriptRoot 'verify_gmax3412_burst_elf.py') (Join-Path $app 'build/FH_Carrier_Test.elf')
if($LASTEXITCODE -ne 0){throw 'Built application failed memory reservation/MMU verification.'}
Write-Host "PASS: v23 installed and application rebuilt. Backup: $backup"
Write-Host 'Start a fresh hardware launch, then select 9 followed by B (start with 4 frames). No hardware has been programmed by this script.'



