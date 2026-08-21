[CmdletBinding()]
param(
    [string]$OutputDirectory = [Environment]::GetFolderPath('Desktop')
)

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$outputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$addonZip = Join-Path $outputDirectory 'BenTools-Addon.zip'
$companionZip = Join-Path $outputDirectory 'BenTools-Companion.zip'
$fullPackageZip = Join-Path $outputDirectory 'BenTools-Full-Package.zip'
$stagingRoot = Join-Path $outputDirectory '.BenTools-Release-Staging'
$addonRoot = Join-Path $stagingRoot 'BenTools'
$companionRoot = Join-Path $stagingRoot 'BenTools Queue Ringer'
$fullPackageRoot = Join-Path $stagingRoot 'Full Package'

$addonExtensions = @('.toc', '.lua', '.xml', '.blp', '.tga', '.dds', '.png', '.jpg', '.jpeg', '.ogg', '.mp3', '.wav', '.ttf')
$excludedAddonTopLevelDirectories = @('.git', 'QueueRingerCompanion', 'release', '.github', 'build', 'dist', 'tests', 'test', 'scripts', '__pycache__')
$companionFiles = @(
    'queue_ringer.py',
    'Start Queue Ringer.bat',
    'Launch WoW with Queue Ringer.bat',
    'requirements.txt',
    'config.example.json'
)

function Copy-AddonFiles([string]$destinationRoot) {
    Get-ChildItem -LiteralPath $projectRoot -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($projectRoot.Length).TrimStart('\')
        $firstPathPart = $relativePath.Split('\')[0]

        if ($excludedAddonTopLevelDirectories -contains $firstPathPart) {
            return
        }

        if ($addonExtensions -notcontains $_.Extension.ToLowerInvariant()) {
            return
        }

        $destination = Join-Path $destinationRoot $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
}

function Copy-CompanionFiles([string]$destinationRoot) {
    $companionSource = Join-Path $projectRoot 'QueueRingerCompanion'
    foreach ($fileName in $companionFiles) {
        $source = Join-Path $companionSource $fileName
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Required companion file is missing: $source"
        }
        Copy-Item -LiteralPath $source -Destination (Join-Path $destinationRoot $fileName) -Force
    }

    @'
# BenTools Queue Ringer Companion

This optional Windows companion requires the **BenTools** addon to be installed in World of Warcraft.

1. Install the BenTools addon first.
2. Install Python 3, then double-click `Start Queue Ringer.bat`.
3. Configure Discord and/or BenTools Phone Notifications in the companion.

For BenTools Phone Notifications:

1. Visit https://focustap.github.io/BenRingerApp/
2. In Safari, choose **Add to Home Screen**.
3. Open the installed app and enable notifications.
4. Paste the pairing code into the companion's BenTools Phone pairing/device code field.

Discord and BenTools Phone Notifications can be enabled independently.
'@ | Set-Content -LiteralPath (Join-Path $destinationRoot 'README.md') -Encoding utf8
}

function Write-FullPackageReadme([string]$destinationPath) {
    @'
BenTools Full Package
=====================

1. Copy the BenTools folder into:
   World of Warcraft\_retail_\Interface\AddOns

2. Optional notifications: run Start Queue Ringer.bat.

Discord is optional. For iPhone notifications:

1. Visit https://focustap.github.io/BenRingerApp/
2. In Safari, choose Add to Home Screen.
3. Open the installed app and enable notifications.
4. Copy the pairing code into the BenTools Queue Ringer companion.
'@ | Set-Content -LiteralPath $destinationPath -Encoding utf8
}

try {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $companionRoot -Force | Out-Null

    Copy-AddonFiles $addonRoot
    if (-not (Test-Path -LiteralPath (Join-Path $addonRoot 'BenTools.toc') -PathType Leaf)) {
        throw 'BenTools.toc was not staged for the addon package.'
    }
    Copy-CompanionFiles $companionRoot

    $fullAddonRoot = Join-Path $fullPackageRoot 'BenTools'
    $fullCompanionRoot = Join-Path $fullPackageRoot 'BenTools Queue Ringer'
    New-Item -ItemType Directory -Path $fullAddonRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $fullCompanionRoot -Force | Out-Null
    Copy-AddonFiles $fullAddonRoot
    Copy-CompanionFiles $fullCompanionRoot

    @'
@echo off
call "%~dp0BenTools Queue Ringer\Start Queue Ringer.bat"
'@ | Set-Content -LiteralPath (Join-Path $fullPackageRoot 'Start Queue Ringer.bat') -Encoding ascii
    @'
@echo off
call "%~dp0BenTools Queue Ringer\Launch WoW with Queue Ringer.bat"
'@ | Set-Content -LiteralPath (Join-Path $fullPackageRoot 'Launch WoW with Queue Ringer.bat') -Encoding ascii
    Write-FullPackageReadme (Join-Path $fullPackageRoot 'README.txt')

    foreach ($zipPath in @($addonZip, $companionZip, $fullPackageZip)) {
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }
    }

    Compress-Archive -LiteralPath $addonRoot -DestinationPath $addonZip -CompressionLevel Optimal
    Compress-Archive -LiteralPath $companionRoot -DestinationPath $companionZip -CompressionLevel Optimal
    Compress-Archive -Path (Join-Path $fullPackageRoot '*') -DestinationPath $fullPackageZip -CompressionLevel Optimal

    Write-Host "Created $addonZip"
    Write-Host "Created $companionZip"
    Write-Host "Created $fullPackageZip"
} finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}
