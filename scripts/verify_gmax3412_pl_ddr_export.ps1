$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1') -ErrorAction Stop
$projectRoot = Split-Path -Parent $PSScriptRoot
$exportDir = Join-Path $projectRoot 'exports/gmax3412_pl_ddr'
$artifactStem = Join-Path $exportDir 'FH_Carrier_Bringup_GMAX3412_PL_DDR'
$timing = Get-Content -LiteralPath (Join-Path $exportDir 'timing.rpt') -Raw
if ($timing -notmatch 'All user specified timing constraints are met\.' -or
    $timing -notmatch 'checking unconstrained_internal_endpoints \(0\)') {
    throw 'Routed timing constraints are not fully met'
}
if ((Get-Content -LiteralPath (Join-Path $exportDir 'bus_skew.rpt') -Raw) -match 'VIOLATED') {
    throw 'Routed bus-skew violation remains'
}
if ((Get-Content -LiteralPath (Join-Path $exportDir 'route_status.rpt') -Raw) -notmatch 'nets with routing errors\.+\s*:\s*0\s*:') {
    throw 'Routing error check failed'
}
if ((Get-Content -LiteralPath (Join-Path $exportDir 'drc.rpt') -Raw) -match 'DCIRST-1|Critical Warning|\| Error') {
    throw 'DDR DCI reset requirement or critical DRC finding remains; export is not qualified'
}
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
        if ($hwh -match 'gmax3412_emulator_0' -and $hwh -match 'A0030000' -and $hwh -match 'A0040000' -and $hwh -match 'A0050000' -and $hwh -match 'A0060000' -and $hwh -match 'gmax_scheduler') {
            [xml]$xml=$hwh
            $dma=$xml.SelectSingleNode("//MODULE[@INSTANCE='gmax_capture_dma']")
            $width=$dma.SelectSingleNode("PARAMETERS/PARAMETER[@NAME='c_addr_width']")
            if(!$width -or $width.VALUE -ne '64') {throw 'Handoff DMA address width is not 64 bits'}
            $high=$dma.SelectSingleNode(".//MEMRANGE[@BASEVALUE='0x800000000']")
            if(!$high -or $high.HIGHVALUE -ne '0x87FFFFFFF') {throw 'DMA high-DDR aperture missing from handoff'}
            $pl=$dma.SelectSingleNode(".//MEMRANGE[@BASEVALUE='0x1000000000']")
            if(!$pl -or $pl.HIGHVALUE -ne '0x10FFFFFFFF'){throw 'DMA 4 GiB PL DDR aperture missing'}
            $ps=$xml.SelectSingleNode("//MODULE[@INSTANCE='zynq_ultra_ps_e_0']")
            $cpuPl=$ps.SelectSingleNode(".//MEMRANGE[@INSTANCE='pl_ddr4'][@BASEVALUE='0x1000000000']")
            if(!$cpuPl -or $cpuPl.HIGHVALUE -ne '0x10FFFFFFFF'){throw 'A53 4 GiB PL DDR aperture missing'}
            $mig=$xml.SelectSingleNode("//MODULE[@INSTANCE='pl_ddr4']")
            $ddrReset=$xml.SelectSingleNode("//MODULE[@INSTANCE='pl_ddr_reset']")
            foreach($name in @('C_EXT_RESET_HIGH','C_AUX_RESET_HIGH')) {
                $setting=$ddrReset.SelectSingleNode("PARAMETERS/PARAMETER[@NAME='$name']")
                $expected=if($name -eq 'C_EXT_RESET_HIGH'){'1'}else{'0'}
                if(!$setting -or $setting.VALUE -ne $expected){throw "Unsafe PL DDR reset polarity: $name"}
            }
            $inactive=$xml.SelectSingleNode("//MODULE[@INSTANCE='pl_ddr_reset_inactive']")
            $constantValue=if($inactive){$inactive.SelectSingleNode("PARAMETERS/PARAMETER[@NAME='CONST_VAL']")}else{$null}
            if(!$constantValue -or [uint64]$constantValue.VALUE -ne 1){throw 'DDR auxiliary inactive-high constant missing'}
            $aux=$ddrReset.SelectSingleNode("PORTS/PORT[@NAME='aux_reset_in']")
            $constant=$inactive.SelectSingleNode("PORTS/PORT[@NAME='dout']")
            if(!$aux -or !$constant -or !$aux.SIGNAME -or $aux.SIGNAME -ne $constant.SIGNAME -or
                !$aux.SelectSingleNode("CONNECTIONS/CONNECTION[@INSTANCE='pl_ddr_reset_inactive'][@PORT='dout']")) {
                throw 'DDR active-low auxiliary reset is not connected to constant one'
            }
            if(!$xml.SelectSingleNode("//MODULE[@INSTANCE='pl_ddr_dci_reset']")){throw 'DDR DCI startup sequencer missing from handoff'}
            foreach($setting in @{
                'C0.DDR4_MemoryPart'='MT40A512M16LY-075';
                'C0.DDR4_DataWidth'='64'; 'C0.DDR4_AxiAddressWidth'='32';
                'C0.DDR4_AxiDataWidth'='512'; 'C0.DDR4_AxiNarrowBurst'='true'
            }.GetEnumerator()) {
                $parameter=$mig.SelectSingleNode("PARAMETERS/PARAMETER[@NAME='$($setting.Key)']")
                if(!$parameter -or $parameter.VALUE -ne $setting.Value){throw "Incorrect exported DDR setting: $($setting.Key)"}
            }
            if($hwh -notmatch 'gmax_pl_ring' -or $hwh -notmatch 'A0070000' -or $hwh -notmatch 'pl_ddr4'){throw 'PL ring/MIG missing'}
            $foundEmulator = $true
        }
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
    Write-Output 'PASS: XSA embeds the exact delivered BIT; PS/DMA 4 GiB PL DDR maps and MIG geometry verified; no critical methodology findings.'
    $hashes | Format-Table -AutoSize
} finally { $archive.Dispose() }


