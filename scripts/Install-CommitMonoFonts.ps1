<#
.SYNOPSIS
    Installs Commit Mono and Commit Mono Nerd Font variants (per-user).
.DESCRIPTION
    Expands font zip archives, shows the user what will be installed,
    installs to the per-user font directory, and cleans up.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step  { param([string]$Message) Write-Host ":: $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Message) Write-Host "   $Message" -ForegroundColor Green }
function Write-Err   { param([string]$Message) Write-Host "   $Message" -ForegroundColor Red }

# --- Paths ---
$fontPath = Join-Path $Env:XDG_DATA_HOME 'chezmoi\lib\fonts\commit-mono'
$archives = @(
#    @{ Zip = 'CommitMono-DarkV143.zip';      Dir = 'CommitMono-DarkV143'      }
#    @{ Zip = 'CommitMono-LightV143.zip';      Dir = 'CommitMono-LightV143'     }
    @{ Zip = 'CommitMono-DarkNerdV143.zip';   Dir = 'CommitMono-DarkNerdV143'  }
    @{ Zip = 'CommitMono-LightNerdV143.zip';  Dir = 'CommitMono-LightNerdV143' }
)

# --- Expand archives ---
Write-Step 'Expanding font archives'
$expandedDirs = @()
foreach ($a in $archives) {
    $zipFile = Join-Path $fontPath $a.Zip
    $destDir = Join-Path $fontPath $a.Dir

    if (-not (Test-Path $zipFile)) {
        Write-Err "Missing archive: $zipFile"; exit 1
    }

    if (Test-Path $destDir) { Remove-Item -Path $destDir -Recurse -Force }
    Expand-Archive -Path $zipFile -DestinationPath $destDir -Force
    $expandedDirs += $destDir
    Write-Ok "Expanded $($a.Zip)"
}

# --- Collect fonts and confirm with user ---
$fonts = @()
foreach ($dir in $expandedDirs) {
    $fonts += Get-ChildItem -Path $dir -Filter '*.otf'
}

if ($fonts.Count -eq 0) {
    Write-Err 'No font files found in archives'; exit 1
}

Write-Step "The following $($fonts.Count) fonts will be installed:"
foreach ($font in $fonts) {
    Write-Host "   $($font.Name)" -ForegroundColor White
}

Write-Host ''
$response = Read-Host '   Proceed with installation? [Y/n]'
if ($response -and $response -notmatch '^[Yy]') {
    Write-Err 'Installation cancelled'
    foreach ($dir in $expandedDirs) { Remove-Item -Path $dir -Recurse -Force }
    exit 0
}

# --- Install fonts (per-user) ---
Write-Step 'Installing fonts'
$userFontDir = Join-Path $Env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
if (-not (Test-Path $userFontDir)) { New-Item -ItemType Directory -Path $userFontDir | Out-Null }
$regPath = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

foreach ($font in $fonts) {
    $destFile = Join-Path $userFontDir $font.Name
    Copy-Item -Path $font.FullName -Destination $destFile -Force
    $fontName = [System.IO.Path]::GetFileNameWithoutExtension($font.Name)
    Set-ItemProperty -Path $regPath -Name "$fontName (OpenType)" -Value $destFile
}
Write-Ok "$($fonts.Count) fonts installed to $userFontDir"

# --- Clean up expanded directories ---
Write-Step 'Cleaning up'
foreach ($dir in $expandedDirs) {
    Remove-Item -Path $dir -Recurse -Force
}
Write-Ok 'Temporary files removed'

Write-Host "`nDone! You may need to restart running applications to use the new fonts." -ForegroundColor Green
