param([string]$Workspace='C:\Projects\VITIS\FH_Carrier_Bringup')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$platform=Join-Path $Workspace 'FH_Carrier_platform'
$app=Join-Path $Workspace 'FH_Carrier_Test'
$source=Join-Path $root 'exports/gmax3412_capture/software/BringupTest_v20.c'
$bit=Join-Path $root 'exports/gmax3412_capture/FH_Carrier_Bringup_GMAX3412_Capture.bit'
$xsa=Join-Path $root 'exports/gmax3412_capture/FH_Carrier_Bringup_GMAX3412_Capture.xsa'
$launch=Join-Path $app '_ide/launch.json'
$target=Join-Path $app 'src/BringupTest.c'
$ninja='C:\AMDDesignTools\2025.2\Vitis\bin\ninja.exe'
$toolchainBin='C:\AMDDesignTools\2025.2\Vitis\gnu\aarch64\nt\aarch64-none\bin'
$sizeTool=Join-Path $toolchainBin 'aarch64-none-elf-size.exe'
foreach($p in @($source,$bit,$xsa,$launch,$target,$ninja,$sizeTool)) {
    if(!(Test-Path -LiteralPath $p)){throw "Missing required file: $p"}
}
$platformXsa=Join-Path $platform 'export/FH_Carrier_platform/hw/FH_Carrier_Bringup_GMAX3412_Capture.xsa'
if((Get-FileHash $platformXsa).Hash -ne (Get-FileHash $xsa).Hash){throw 'Platform XSA does not match capture export. Update and rebuild platform first.'}
$fsblSource=Join-Path $platform 'zynqmp_fsbl/psu_init.c'
$generated=Join-Path $platform 'zynqmp_fsbl/zynqmp_fsbl_bsp/hw_artifacts/psu_init.c'
if((Get-FileHash $fsblSource).Hash -ne (Get-FileHash $generated).Hash){throw 'FSBL initialization source differs from current generated hardware. Reconcile before continuing.'}
$config=Get-Content -LiteralPath $launch -Raw | ConvertFrom-Json
$matches=@($config.configurations | Where-Object {$_.name -eq 'FH_Carrier_Test_app_hw_1'})
if($matches.Count -ne 1){throw 'Expected one FH_Carrier_Test_app_hw_1 launch configuration.'}
$backup=Join-Path $Workspace ('v20_backup_'+[Guid]::NewGuid().ToString('N'))
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
Write-Host "PASS: v20 installed and application rebuilt. Backup: $backup"
Write-Host 'Start a fresh hardware launch, then select T. No hardware has been programmed by this script.'
