# Preserve the current layout; run locally to stage, commit, tag and optionally push.
[CmdletBinding()]
param(
    [switch]$Push,
    [switch]$Preview
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "Git command failed: $args" }
}
$tag = 'v24-hardware-tests-passed'
$message = 'v24 hardware tests passed'
$remote = 'FH_Carrier_Vivado'
$branch = (Invoke-Git symbolic-ref --quiet --short HEAD).Trim()
if (!$branch) { throw 'Check out a branch before running this script.' }
$repo = (Invoke-Git rev-parse --show-toplevel).Trim()
if ((Resolve-Path -LiteralPath $repo).Path -ne (Resolve-Path -LiteralPath $root).Path) {
    throw 'This script must be inside the intended repository root.'
}
$urls = @(Invoke-Git remote get-url --push --all $remote)
if ($urls.Count -ne 1 -or $urls[0] -notmatch '^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)FerranLisa/FH_Carrier_Vivado(?:\.git)?/?$') {
    throw 'The Vivado push remote is missing or points to an unexpected repository. No changes made.'
}
foreach ($name in @('MERGE_HEAD','CHERRY_PICK_HEAD','REVERT_HEAD','rebase-merge','rebase-apply')) {
    $path = (Invoke-Git rev-parse --git-path $name).Trim()
    if (Test-Path -LiteralPath $path) { throw "Finish the active Git operation first: $name" }
}
foreach ($path in @(
    '.gitignore','FH_Carrier_Bringup.xpr',
    'FH_Carrier_Bringup.srcs/sources_1/bd/design_1/design_1.bd',
    'ip/gmax3412_pl_ring/component.xml','software/BringupTest_v24.c',
    'exports/gmax3412_pl_ddr/software/BringupTest_v24.c',
    'exports/gmax3412_pl_ddr/software/lscript_v24.ld',
    'scripts/build_gmax3412_pl_ddr_export.tcl',
    'scripts/prepare_vitis_v24.ps1','tests/tb_gmax3412_pl_ring.sv',
    'audit/pl_ddr4/vendor_ddr.xdc','audit/pl_ddr4/routed_assigned_addresses.json',
    'audit/pl_ddr4/v24_hardware_tests.txt','audit/pl_ddr4/GUI_RESULTS.md'
)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required source/evidence missing: $path" }
    & git check-ignore --no-index --quiet -- $path
    if ($LASTEXITCODE -eq 0) { throw "Required source is ignored: $path" }
    if ($LASTEXITCODE -ne 1) { throw "Cannot check ignore rules for $path" }
}
$existing = @(Invoke-Git tag --list $tag)
Write-Host "Repository: $root"
Write-Host "Branch: $branch; tag: $tag"
Write-Host "Push destination: $($urls[0])"
if ($Preview) {
    Write-Host 'PREVIEW ONLY: no files, Git index, commit, tag or remote will be changed.'
    Write-Host 'Tracked generated files that will be untracked (local copies kept):'
    Invoke-Git -c core.quotepath=false ls-files --cached --ignored --exclude-standard
    Write-Host 'Current changes, including non-ignored untracked files:'
    Invoke-Git status --short --untracked-files=all
    if ($existing.Count) { Write-Host 'The release tag already exists; execution will require a clean worktree and that tag at HEAD.' }
    return
}
if ($existing.Count) {
    # Supports retrying a failed push without creating another commit/tag.
    $tagCommit = (Invoke-Git rev-parse "refs/tags/$tag^{commit}").Trim()
    $head = (Invoke-Git rev-parse HEAD).Trim()
    if ($tagCommit -ne $head -or @(Invoke-Git status --porcelain).Count -ne 0) {
        throw "Tag $tag already exists. It is never overwritten; retry requires clean files and HEAD at that tag."
    }
    Write-Host 'Existing release is already committed and tagged; reusing it.'
} else {
    Invoke-Git var GIT_AUTHOR_IDENT | Out-Null
    Invoke-Git var GIT_COMMITTER_IDENT | Out-Null
# Remove generated files from the index only. Preserve every working file.
$ignored = @(Invoke-Git -c core.quotepath=false ls-files --cached --ignored --exclude-standard)
foreach ($path in $ignored) { Invoke-Git rm --cached -f -- $path }
Invoke-Git add -A -- .
$remaining = @(Invoke-Git ls-files --cached --ignored --exclude-standard)
if ($remaining.Count -ne 0) { throw 'Ignored files remain staged' }
# Reject oversized source blobs before attempting a GitHub push.
$objects = @(Invoke-Git ls-files --stage)
$ids = @($objects | ForEach-Object { ($_ -split '\s+',4)[1] } | Sort-Object -Unique)
$sizes = @($ids | & git cat-file '--batch-check=%(objectname) %(objectsize)')
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect staged object sizes' }
foreach ($entry in $sizes) {
    $parts = $entry -split ' '
    if ([long]$parts[1] -ge 100MB) { throw "Staged object exceeds 100 MiB: $($parts[0]). Update ignore rules before committing." }
}
Invoke-Git diff --cached --stat
& git diff --cached --quiet
$diffCode = $LASTEXITCODE
if ($diffCode -eq 1) {
    Invoke-Git commit -m $message
} elseif ($diffCode -eq 0) {
    if ((Invoke-Git log -1 --format=%s).Trim() -ne $message) {
        throw 'Nothing to commit and HEAD is not the expected release commit.'
    }
} else { throw 'Cannot inspect staged differences' }
Invoke-Git tag -a $tag -m $message
}
if ($Push) {
    # Push only this branch and this tag, together. Never force or push all tags.
    Invoke-Git push --atomic $remote "HEAD:refs/heads/$branch" "refs/tags/$tag`:refs/tags/$tag"
    Write-Host "Pushed $branch and $tag to $remote."
} else {
    Write-Host 'Local commit/tag complete. Run again with -Push to publish.'
}
Invoke-Git log -1 --format=fuller
Invoke-Git status --short
