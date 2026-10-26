$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    # Low image base models this application's <2 GiB DMA address requirement.
    & cmd.exe /d /c 'call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul && cl.exe /nologo /TC /O2 /W3 /WX tests\test_gmax3412_ring_host.c /Fo:results\test_gmax3412_ring_host.obj /Fe:results\test_gmax3412_ring_host.exe /link /BASE:0x400000 /DYNAMICBASE:NO /IGNORE:4281'
    if($LASTEXITCODE -ne 0){throw 'Host test build failed'}
    & .\results\test_gmax3412_ring_host.exe
    if($LASTEXITCODE -ne 0){throw 'Ring host tests failed'}
} finally {Pop-Location}
