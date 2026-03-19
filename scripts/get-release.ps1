<#
.SYNOPSIS
    Download the latest PepperDash Essentials release CPZ from GitHub.

.DESCRIPTION
    Queries the GitHub releases API for the latest PepperDash Essentials release
    and downloads the .net472.cpz asset to the local releases/ directory.

.PARAMETER Version
    Specific version tag to download (e.g. 'v2.28.0'). Defaults to latest release.

.PARAMETER OutputDir
    Directory to save the CPZ file. Default: <repo-root>\releases

.EXAMPLE
    .\scripts\get-release.ps1
    Download the latest release.

.EXAMPLE
    .\scripts\get-release.ps1 -Version v2.27.0
    Download a specific version.
#>

[CmdletBinding()]
param(
    [string] $Version,
    [string] $OutputDir
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function Write-Step([string] $msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Write-Success([string] $msg) {
    Write-Host "    OK  $msg" -ForegroundColor Green
}

if (-not $OutputDir) {
    $OutputDir = Join-Path $root 'releases'
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# ─── Query GitHub releases API ────────────────────────────────────────────────

$apiBase = 'https://api.github.com/repos/PepperDash/Essentials/releases'

if ($Version) {
    Write-Step "Fetching release info for $Version ..."
    $release = Invoke-RestMethod -Uri "$apiBase/tags/$Version" -Headers @{ 'User-Agent' = 'ps-get-release' }
} else {
    Write-Step "Fetching latest release info ..."
    $release = Invoke-RestMethod -Uri "$apiBase/latest" -Headers @{ 'User-Agent' = 'ps-get-release' }
}

Write-Host "    Tag     : $($release.tag_name)"
Write-Host "    Date    : $($release.published_at)"
Write-Host "    Name    : $($release.name)"

# ─── Find CPZ asset ───────────────────────────────────────────────────────────

$asset = $release.assets | Where-Object { $_.name -like '*.net472.cpz' } | Select-Object -First 1

if (-not $asset) {
    throw "No .net472.cpz asset found in release $($release.tag_name)."
}

$outPath = Join-Path $OutputDir $asset.name

if (Test-Path $outPath) {
    Write-Host "`n    Already downloaded: $($asset.name)" -ForegroundColor Yellow
    Write-Host "    Delete $outPath to re-download."
    exit 0
}

# ─── Download ─────────────────────────────────────────────────────────────────

Write-Step "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB) ..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $outPath
Write-Success "$outPath"

Write-Host "`nRelease downloaded." -ForegroundColor Green
Write-Host "  Version : $($release.tag_name)"
Write-Host "  File    : $outPath"
