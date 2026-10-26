param([string]$Workspace='C:\Projects\VITIS\FH_Carrier_Bringup')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$bsp=Join-Path $Workspace 'FH_Carrier_platform/export/FH_Carrier_platform/sw/standalone_psu_cortexa53_0'
$out=Join-Path $root 'exports/gmax3412_scheduler/software'
$gcc='C:/AMDDesignTools/2025.2/Vitis/gnu/aarch64/nt/aarch64-none/bin/aarch64-none-elf-gcc.exe'
$python='C:/AMDDesignTools/2025.2/tps/win64/python-3.13.0/python.exe'
& $python (Join-Path $PSScriptRoot 'create_bringup_v23.py')
if($LASTEXITCODE -ne 0){throw 'Source generation failed'}
& $gcc -std=gnu11 -DSDT -mcpu=cortex-a53 -Wall -Wextra -Werror -O0 -g3 "-specs=$bsp/Xilinx.spec" -I "$bsp/include" (Join-Path $root 'software/BringupTest_v23.c') -o "$out/BringupTest_v23.elf" "-Wl,-T,$out/lscript_v23.ld" "-Wl,-Map,$out/BringupTest_v23.map" "-L$bsp/lib" '-Wl,--start-group' -lxilstandalone -lxiltimer -lxil -lgcc -lc '-Wl,--end-group'
if($LASTEXITCODE -ne 0){throw 'A53 compile/link failed'}
& $python (Join-Path $PSScriptRoot 'verify_gmax3412_burst_elf.py') "$out/BringupTest_v23.elf"
if($LASTEXITCODE -ne 0){throw 'ELF memory validation failed'}
$hashes=foreach($name in @('BringupTest_v23.c','BringupTest_v23.elf','lscript_v23.ld')) {
    $hash=Get-FileHash -LiteralPath (Join-Path $out $name) -Algorithm SHA256
    [pscustomobject]@{File=$name;SHA256=$hash.Hash}
}
$hashes | ConvertTo-Json | Set-Content (Join-Path $out 'SHA256.json') -Encoding utf8
Write-Output 'BRINGUP_V23_BUILD_PASS'
