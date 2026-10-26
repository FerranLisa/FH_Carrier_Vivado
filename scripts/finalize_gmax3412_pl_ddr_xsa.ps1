# Vivado's project-mode export can select impl_1's old BIT even after an
# in-process build. Bind the exported handoff to the explicitly named new BIT.
# Keep all Vivado-generated metadata and archive entry names intact.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1') -ErrorAction Stop
$projectRoot = Split-Path -Parent $PSScriptRoot
$exportDir = Join-Path $projectRoot 'exports/gmax3412_pl_ddr'
$stem = Join-Path $exportDir 'FH_Carrier_Bringup_GMAX3412_PL_DDR'
$temporary = "$stem.finalizing.xsa"
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
if (-not (Test-Path -LiteralPath "$stem.bit")) { throw 'New bitstream missing' }
Copy-Item -LiteralPath "$stem.xsa" -Destination $temporary -Force
$archive = [System.IO.Compression.ZipFile]::Open($temporary, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    $entries = @($archive.Entries | Where-Object { $_.FullName -like '*.bit' })
    if ($entries.Count -ne 1) { throw 'Expected exactly one bitstream entry' }
    $name = $entries[0].FullName
    # Preserve Vivado's internal filename and all manifest references, whether
    # export was made from an open design or from the project after DCP closure.
    $reader = [System.IO.StreamReader]::new($archive.GetEntry('design_1.hwh').Open())
    try { $handoff = $reader.ReadToEnd() } finally { $reader.Dispose() }
    if ($handoff -notmatch 'gmax3412_emulator_0' -or $handoff -notmatch 'A0030000' -or
        $handoff -notmatch 'No_buffer') { throw 'Handoff does not contain the corrected emulator design' }
    $entries[0].Delete()
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, "$stem.bit", $name, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
} finally { $archive.Dispose() }
# Verify before replacing the deliverable.
$archive = [System.IO.Compression.ZipFile]::OpenRead($temporary)
try {
    $stream = $archive.GetEntry($name).Open()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $embedded = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($embedded -ne (Get-FileHash -LiteralPath "$stem.bit" -Algorithm SHA256).Hash) {
        throw 'Finalized XSA bitstream hash mismatch'
    }
} finally { $archive.Dispose() }
Move-Item -LiteralPath $temporary -Destination "$stem.xsa" -Force
& (Join-Path $PSScriptRoot 'verify_gmax3412_pl_ddr_export.ps1')


