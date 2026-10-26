$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1') -ErrorAction Stop
$projectRoot = Split-Path -Parent $PSScriptRoot
$exportDir = Join-Path $projectRoot 'exports/gmax3412_timing'
$artifactStem = Join-Path $exportDir 'FH_Carrier_Bringup_GMAX3412_Timing'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead("$artifactStem.xsa")
try {
    $bitEntries = @($archive.Entries | Where-Object { $_.FullName -like '*.bit' })
    if ($bitEntries.Count -ne 1) { throw "Expected exactly one embedded bitstream, got $($bitEntries.Count)" }
    $stream = $bitEntries[0].Open()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $embeddedHash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
    $localHash = (Get-FileHash -LiteralPath "$artifactStem.bit" -Algorithm SHA256).Hash
    if ($embeddedHash -ne $localHash) { throw 'XSA embeds a different bitstream from the delivered BIT' }
    $hwhEntries = @($archive.Entries | Where-Object { $_.FullName -like '*.hwh' })
    if ($hwhEntries.Count -eq 0) { throw 'XSA has no hardware handoff description' }
    $foundEmulator = $false
    foreach ($entry in $hwhEntries) {
        $reader = [System.IO.StreamReader]::new($entry.Open())
        try { $hwh = $reader.ReadToEnd() } finally { $reader.Dispose() }
        if ($hwh -match 'gmax3412_emulator_0' -and $hwh -match 'A0030000' -and $hwh -match 'A0040000' -and $hwh -match 'A0050000' -and $hwh -match 'gmax_capture_dma') { $foundEmulator = $true }
    }
    if (-not $foundEmulator) { throw 'Emulator/address missing from XSA hardware handoff' }
    if ((Get-Content -LiteralPath (Join-Path $exportDir 'methodology.rpt') -Raw) -match 'Critical Warning') {
        throw 'Critical methodology findings remain'
    }
    $hashes = foreach ($suffix in @('bit', 'ltx', 'xsa')) {
        $item = Get-FileHash -LiteralPath "$artifactStem.$suffix" -Algorithm SHA256
        [pscustomobject]@{ File = Split-Path -Leaf $item.Path; SHA256 = $item.Hash }
    }
    $hashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $exportDir 'SHA256.json') -Encoding utf8
    Write-Output 'PASS: XSA embeds the exact delivered BIT; emulator/address present; no critical methodology findings.'
    $hashes | Format-Table -AutoSize
} finally { $archive.Dispose() }

