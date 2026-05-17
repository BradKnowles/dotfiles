<#
.SYNOPSIS
    Patches Commit Mono fonts with Nerd Fonts glyphs using Docker.
.DESCRIPTION
    Expands source zip archives if needed, pulls the nerdfonts/patcher image,
    patches both Dark and Light variants, zips the results, and cleans up.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step  { param([string]$Message) Write-Host ":: $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Message) Write-Host "   $Message" -ForegroundColor Green }
function Write-Skip  { param([string]$Message) Write-Host "   $Message" -ForegroundColor Yellow }
function Write-Err   { param([string]$Message) Write-Host "   $Message" -ForegroundColor Red }

# --- Check Docker ---
Write-Step 'Checking Docker'
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Err 'docker is not installed or not on PATH'; exit 1
}
docker info *>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err 'Docker daemon is not running — start Docker Desktop and try again'; exit 1
}
Write-Ok 'Docker is running'

# --- Paths ---
$fontPath  = Join-Path $Env:USERPROFILE '.local\share\chezmoi\lib\fonts\commit-mono'
$variants  = @(
    @{ Name = 'Dark';  Zip = 'CommitMono-DarkV143.zip';  Dir = 'CommitMono-DarkV143';  NerdDir = 'CommitMono-DarkNerdV143';  NerdZip = 'CommitMono-DarkNerdV143.zip'  }
    @{ Name = 'Light'; Zip = 'CommitMono-LightV143.zip'; Dir = 'CommitMono-LightV143'; NerdDir = 'CommitMono-LightNerdV143'; NerdZip = 'CommitMono-LightNerdV143.zip' }
)

# --- Clean all directories ---
Write-Step 'Cleaning all font directories'
foreach ($v in $variants) {
    foreach ($dir in @($v.Dir, $v.NerdDir)) {
        $fullPath = Join-Path $fontPath $dir
        if (Test-Path $fullPath) {
            Remove-Item -Path $fullPath -Recurse -Force
            Write-Ok "Removed $dir"
        }
    }
}

# --- Extract source fonts ---
Write-Step 'Extracting source fonts'
foreach ($v in $variants) {
    $zipFile = Join-Path $fontPath $v.Zip
    $destDir = Join-Path $fontPath $v.Dir

    if (-not (Test-Path $zipFile)) {
        Write-Err "Missing archive: $zipFile"; exit 1
    }

    Expand-Archive -Path $zipFile -DestinationPath $destDir -Force
    Write-Ok "Extracted $($v.Zip)"
}

# --- Pull patcher image ---
Write-Step 'Pulling nerdfonts/patcher image'
docker pull nerdfonts/patcher
if ($LASTEXITCODE -ne 0) {
    Write-Err 'Failed to pull nerdfonts/patcher'; exit 1
}
Write-Ok 'Image ready'

# --- Create output directories ---
foreach ($v in $variants) {
    New-Item -ItemType Directory -Path (Join-Path $fontPath $v.NerdDir) | Out-Null
}

# --- Patch fonts ---
foreach ($v in $variants) {
    $srcDir = Join-Path $fontPath $v.Dir
    $outDir = Join-Path $fontPath $v.NerdDir

    Write-Step "Patching $($v.Name) variant"
    docker run --rm -v "${srcDir}:/in:Z" -v "${outDir}:/out:Z" nerdfonts/patcher --complete
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Patching $($v.Name) failed"; exit 1
    }
    Write-Ok "$($v.Name) patched"
}

# --- Zip patched fonts and clean up ---
Write-Step 'Zipping patched fonts'
foreach ($v in $variants) {
    $outDir  = Join-Path $fontPath $v.NerdDir
    $zipFile = Join-Path $fontPath $v.NerdZip

    if (Test-Path $zipFile) { Remove-Item -Path $zipFile -Force }
    Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zipFile
    Write-Ok "Created $($v.NerdZip)"

    Remove-Item -Path $outDir -Recurse -Force
    Write-Ok "Removed $($v.NerdDir)"
}

# --- Clean up source directories ---
Write-Step 'Cleaning up source directories'
foreach ($v in $variants) {
    $srcDir = Join-Path $fontPath $v.Dir
    if (Test-Path $srcDir) {
        Remove-Item -Path $srcDir -Recurse -Force
        Write-Ok "Removed $($v.Dir)"
    }
}

Write-Host "`nDone! Nerd Font archives created:" -ForegroundColor Green
foreach ($v in $variants) {
    Write-Host "   $(Join-Path $fontPath $v.NerdZip)" -ForegroundColor Green
}
