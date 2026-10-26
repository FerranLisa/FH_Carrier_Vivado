param([string]$Workspace='C:\Projects\VITIS\FH_Carrier_Bringup',[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$platform=Join-Path $Workspace 'FH_Carrier_platform'
$app=Join-Path $Workspace 'FH_Carrier_Test'
$source=Join-Path $root 'exports/gmax3412_ring/software/BringupTest_v22.c'
$bit=Join-Path $root 'exports/gmax3412_timing/FH_Carrier_Bringup_GMAX3412_Timing.bit'
$xsa=Join-Path $root 'exports/gmax3412_timing/FH_Carrier_Bringup_GMAX3412_Timing.xsa'
$launch=Join-Path $app '_ide/launch.json'
$target=Join-Path $app 'src/BringupTest.c'
$ninja='C:\AMDDesignTools\2025.2\Vitis\bin\ninja.exe'
$toolchainBin='C:\AMDDesignTools\2025.2\Vitis\gnu\aarch64\nt\aarch64-none\bin'
$sizeTool=Join-Path $toolchainBin 'aarch64-none-elf-size.exe'
foreach($p in @($source,$bit,$xsa,$launch,$target,$ninja,$sizeTool)) {
    if(!(Test-Path -LiteralPath $p)){throw "Missing required file: $p"}
}
$platformXsas=@(Get-ChildItem -LiteralPath (Join-Path $platform 'export/FH_Carrier_platform/hw') -Filter '*.xsa')
if($platformXsas.Count -ne 1){throw 'Expected exactly one exported platform XSA.'}
$platformXsa=$platformXsas[0].FullName
# This software-only revision uses the hardware-qualified Timing BIT/XSA.
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
        throw "Platform PS initialization differs ($name). Update platform from Timing XSA and rebuild first."
    }
}
$params=Get-Content -LiteralPath (Join-Path $platform 'export/FH_Carrier_platform/sw/standalone_psu_cortexa53_0/include/xparameters.h') -Raw
if($params -notmatch '(?i)XPAR_GMAX_CAPTURE_CTRL_BASEADDR\s+0xa0040000' -or $params -notmatch '(?i)XPAR_GMAX_CAPTURE_DMA_BASEADDR\s+0xa0050000') {throw 'Capture peripherals missing from BSP.'}
& (Join-Path $PSScriptRoot 'verify_gmax3412_timing_export.ps1')
$fsblSource=Join-Path $platform 'zynqmp_fsbl/psu_init.c'
$generated=Join-Path $platform 'zynqmp_fsbl/zynqmp_fsbl_bsp/hw_artifacts/psu_init.c'
if((Get-FileHash $fsblSource).Hash -ne (Get-FileHash $generated).Hash){throw 'FSBL initialization source differs from current generated hardware. Reconcile before continuing.'}
$config=Get-Content -LiteralPath $launch -Raw | ConvertFrom-Json
$matches=@($config.configurations | Where-Object {$_.name -eq 'FH_Carrier_Test_app_hw_1'})
if($matches.Count -ne 1){throw 'Expected one FH_Carrier_Test_app_hw_1 launch configuration.'}
if($ValidateOnly) {Write-Host 'PASS: v22 preparation prerequisites validated; Vitis files unchanged.';return}
$backup=Join-Path $Workspace ('v22_backup_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'BringupTest.c')
Copy-Item -LiteralPath $launch -Destination (Join-Path $backup 'launch.json')
Copy-Item -LiteralPath $source -Destination $target
$matches[0].targetSetup.bitstreamFile=$bit
$matches[0].targetSetup.programDevice=$true
$matches[0].targetSetup.resetSystem=$true
$config | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $launch -Encoding UTF8
$previousPath=$env:PATH
try {
    # Generated Ninja post-link commands invoke size by name, unlike gcc.
    # Supply the Vitis toolchain to child processes without changing system PATH.
    $env:PATH=$toolchainBin+';'+$previousPath
    & $ninja -C (Join-Path $app 'build')
    if($LASTEXITCODE -ne 0){throw "Application build failed. Backups: $backup"}
} finally {
    $env:PATH=$previousPath
}
if((Get-FileHash $source).Hash -ne (Get-FileHash $target).Hash){throw 'Installed source verification failed.'}
Write-Host "PASS: v22 installed and application rebuilt. Backup: $backup"
Write-Host 'Start a fresh hardware launch, then select S. No hardware has been programmed by this script.'


