[CmdletBinding()]
param(
    [string]$WowAddOnsPath = 'C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns'
)

$ErrorActionPreference = 'Stop'

$sourcePath = $PSScriptRoot
$wowAddOnsPath = [System.IO.Path]::GetFullPath($WowAddOnsPath)
$destinationPath = Join-Path $wowAddOnsPath 'BenToolsRelease'

if (-not (Test-Path -LiteralPath $wowAddOnsPath -PathType Container)) {
    throw "WoW AddOns directory was not found: $wowAddOnsPath"
}

# This is deliberately an exact, fixed deployment destination.  It keeps the
# original BenTools folder untouched and allows WoW to create BenToolsRelease.lua
# for this test add-on's SavedVariables.
if ([System.IO.Path]::GetFileName($destinationPath) -ne 'BenToolsRelease') {
    throw "Refusing to deploy outside the BenToolsRelease test folder."
}

$excludedTopLevelDirectories = @('.git', 'release', 'QueueRingerCompanion', '.github', 'build', 'dist', 'node_modules')
$addonExtensions = @('.lua', '.toc', '.xml', '.blp', '.tga', '.dds', '.png', '.jpg', '.jpeg', '.mp3', '.ogg', '.wav')

if (Test-Path -LiteralPath $destinationPath) {
    Get-ChildItem -LiteralPath $destinationPath -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $destinationPath | Out-Null
}

Get-ChildItem -LiteralPath $sourcePath -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($sourcePath.Length).TrimStart('\')
    $firstPathPart = $relativePath.Split('\')[0]

    if ($excludedTopLevelDirectories -contains $firstPathPart) {
        return
    }

    if ($addonExtensions -notcontains $_.Extension.ToLowerInvariant()) {
        return
    }

    $targetPath = Join-Path $destinationPath $relativePath
    $targetDirectory = Split-Path -Parent $targetPath
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
}

$tocPath = Join-Path $destinationPath 'BenTools.toc'
if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Expected add-on manifest was not deployed: $tocPath"
}

# Stage a test-only identity.  Development files retain BenTools / BenToolsDB;
# the deployed copy becomes BenToolsRelease / BenToolsReleaseDB.
Get-ChildItem -LiteralPath $destinationPath -Recurse -Filter '*.lua' -File | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName)
    $content = $content -replace '\bBenToolsDB\b', 'BenToolsReleaseDB'
    [System.IO.File]::WriteAllText($_.FullName, $content, [System.Text.UTF8Encoding]::new($false))
}

$tocContent = [System.IO.File]::ReadAllText($tocPath)
$tocContent = $tocContent -replace '(?m)^## Title: BenTools$', '## Title: BenTools Release'
$tocContent = $tocContent -replace '(?m)^## SavedVariables: BenToolsDB$', '## SavedVariables: BenToolsReleaseDB'
[System.IO.File]::WriteAllText($tocPath, $tocContent, [System.Text.UTF8Encoding]::new($false))

Write-Host "Deployed BenToolsRelease to $destinationPath"
Write-Host 'SavedVariables are isolated as BenToolsReleaseDB (BenToolsRelease.lua).'
