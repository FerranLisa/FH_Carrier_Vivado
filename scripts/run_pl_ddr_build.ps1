$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
New-Item -ItemType Directory -Path results -Force | Out-Null
Set-Content -LiteralPath results/pl_ddr_build_exit.txt -Value 'RUNNING'
& 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' -mode batch -source scripts/build_gmax3412_pl_ddr_export.tcl -log results/pl_ddr_build.log -journal results/pl_ddr_build.jou *> results/pl_ddr_build_console.txt
$result=$LASTEXITCODE
Set-Content -LiteralPath results/pl_ddr_build_exit.txt -Value $result
exit $result
