<#
.SYNOPSIS
    Build and deploy the Mobile Control React UI to a Crestron 4-series processor.

.DESCRIPTION
    Builds the React app (npm run build:app) then SFTPs the output to the processor
    at /user/program{slot}/mcUserApp/, which is where MobileControlWebsocketServer
    serves static files for the /mc/app route.

    The processor serves:
      GET /mc/app/*  →  /user/program{slot}/mcUserApp/*
      GET /mc/app/   →  /user/program{slot}/mcUserApp/index.html

    Touchpanel URL after deploy:
      http://<ProcessorIp>:50002/mc/app        (room-list mode)
      http://<ProcessorIp>:50002/mc/app?token= (token mode)

.PARAMETER ProcessorIp
    IP address or hostname of the Crestron processor. Mandatory.

.PARAMETER Slot
    Program slot number (1-10). Default: 1.

.PARAMETER Username
    SFTP username. Default: admin.

.PARAMETER Password
    SFTP password. Default: blank.

.PARAMETER SkipBuild
    Skip the npm build step and use the existing dist-app/ folder.

.EXAMPLE
    .\scripts\deploy-ui.ps1 -ProcessorIp 192.168.104.171
    Build and deploy the UI to slot 1.

.EXAMPLE
    .\scripts\deploy-ui.ps1 -ProcessorIp 192.168.104.171 -SkipBuild
    Deploy the existing dist-app/ without rebuilding.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ProcessorIp,

    [ValidateRange(1, 10)]
    [int]    $Slot     = 0,    # 0 = unset; resolved from .env or defaulted to 1 below

    [string] $Username,
    [string] $Password,

    [switch] $SkipBuild
)

$ErrorActionPreference = 'Stop'
$root   = Split-Path $PSScriptRoot -Parent

# ─── Load .env defaults ───────────────────────────────────────────────────────

. "$PSScriptRoot\load-env.ps1"
$envCfg = Read-EnvFile (Join-Path $root '.env')

if (-not $PSBoundParameters.ContainsKey('ProcessorIp') -and $envCfg['PROCESSOR_IP']) {
    $ProcessorIp = $envCfg['PROCESSOR_IP']
}
if ((-not $PSBoundParameters.ContainsKey('Slot') -or $Slot -eq 0) -and $envCfg['PROCESSOR_SLOT']) {
    $Slot = [int]$envCfg['PROCESSOR_SLOT']
}
if (-not $PSBoundParameters.ContainsKey('Username')) {
    $Username = if ($envCfg['PROCESSOR_USERNAME']) { $envCfg['PROCESSOR_USERNAME'] } else { 'admin' }
}
if (-not $PSBoundParameters.ContainsKey('Password')) {
    $Password = if ($envCfg['PROCESSOR_PASSWORD']) { $envCfg['PROCESSOR_PASSWORD'] } else { '' }
}
if ($Slot -eq 0) { $Slot = 1 }

if (-not $ProcessorIp) {
    throw "ProcessorIp is required. Pass -ProcessorIp or set PROCESSOR_IP in .env"
}
$uiRoot = Join-Path $root 'mobile-control-ui'
$distDir = Join-Path $uiRoot 'dist-app'

function Write-Step([string] $msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK([string] $msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }

# ─── Build ────────────────────────────────────────────────────────────────────

if (-not $SkipBuild) {
    Write-Step "Building React app..."
    Push-Location $uiRoot
    try {
        npm run build:app
        if ($LASTEXITCODE -ne 0) { throw "npm run build:app failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
    Write-OK "Build complete → dist-app/"
}

if (-not (Test-Path $distDir)) {
    throw "dist-app/ not found at $distDir. Run without -SkipBuild or run 'npm run build:app' first."
}

$files = Get-ChildItem -Path $distDir -Recurse -File
Write-Step "Files to upload: $($files.Count) files from dist-app/"

# ─── Posh-SSH ─────────────────────────────────────────────────────────────────

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Step "Installing Posh-SSH module..."
    Install-Module -Name Posh-SSH -Force -Scope CurrentUser
}
Import-Module Posh-SSH

$securePassword = if ([string]::IsNullOrEmpty($Password)) {
    New-Object System.Security.SecureString
} else {
    ConvertTo-SecureString $Password -AsPlainText -Force
}
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

# ─── Upload ───────────────────────────────────────────────────────────────────

$remoteBase = "/user/program$Slot/mcUserApp"

Write-Step "Uploading to sftp://$ProcessorIp$remoteBase/ ..."

if ($PSCmdlet.ShouldProcess("$ProcessorIp$remoteBase", 'SFTP upload')) {
    $session = New-SFTPSession -ComputerName $ProcessorIp -Credential $credential -AcceptKey -Force
    try {
        # Ensure base directory exists
        if (-not (Test-SFTPPath -SessionId $session.SessionId -Path $remoteBase)) {
            Write-Host "    Creating $remoteBase ..."
            $session.Session.CreateDirectory($remoteBase)
        }

        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($distDir.Length).Replace('\', '/')
            $remoteDir    = $remoteBase + ($relativePath | Split-Path -Parent).Replace('\', '/')
            $remotePath   = $remoteBase + $relativePath

            if (-not (Test-SFTPPath -SessionId $session.SessionId -Path $remoteDir)) {
                Write-Host "    mkdir $remoteDir"
                # Create each missing directory segment
                $parts = $remoteDir.TrimStart('/').Split('/')
                $built = ''
                foreach ($part in $parts) {
                    $built += "/$part"
                    if (-not (Test-SFTPPath -SessionId $session.SessionId -Path $built)) {
                        $session.Session.CreateDirectory($built)
                    }
                }
            }

            Write-Host "    -> $remotePath"
            Set-SFTPItem -SessionId $session.SessionId -Path $file.FullName -Destination $remoteDir -Force
        }
    } finally {
        Remove-SFTPSession -SessionId $session.SessionId | Out-Null
    }
}

Write-Host ""
Write-Host "UI deploy complete." -ForegroundColor Green
Write-Host "  Processor : $ProcessorIp"
Write-Host "  Slot      : $Slot"
Write-Host "  Remote    : /user/program$Slot/mcUserApp/"
Write-Host ""
Write-Host "Touchpanel URL (room-list mode, no token):"
Write-Host "  http://$($ProcessorIp):50002/mc/app" -ForegroundColor Yellow
