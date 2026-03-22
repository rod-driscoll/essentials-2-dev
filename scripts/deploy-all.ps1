<#
.SYNOPSIS
    Deploy PepperDash Essentials and open the mobile control UI.

.DESCRIPTION
    Convenience wrapper that deploys the Essentials CPZ and configurationFile.json
    to the Crestron processor, then starts the mobile control React dev server.

    Note: There is no separate touchpanel deployment — the mobile control UI is
    a browser-based web app accessed from any device on the network.

.PARAMETER ProcessorIp
    IP address of the Crestron processor. Default: 192.168.104.171.

.PARAMETER Slot
    Program slot number (1-10). Default: 1.

.PARAMETER Username
    Processor SFTP/SSH username. Default: admin.

.PARAMETER Password
    Processor SFTP/SSH password. Default: blank.

.PARAMETER SkipDeploy
    Skip the processor deploy step (useful when just restarting the UI).

.PARAMETER SkipUi
    Skip starting the React dev server.

.EXAMPLE
    .\scripts\deploy-all.ps1
    Deploy to default processor IP and start the UI.

.EXAMPLE
    .\scripts\deploy-all.ps1 -ProcessorIp 192.168.104.171 -SkipUi
    Deploy to processor only.

.EXAMPLE
    .\scripts\deploy-all.ps1 -SkipDeploy
    Start the mobile control UI dev server only.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ProcessorIp,

    [ValidateRange(1, 10)]
    [int]    $Slot        = 0,    # 0 = unset; resolved from .env or defaulted to 1 below

    [string] $Username,
    [string] $Password,

    [switch] $SkipDeploy,
    [switch] $SkipUi
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

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

function Write-Banner([string] $msg) {
    $bar = '─' * ($msg.Length + 4)
    Write-Host "`n$bar" -ForegroundColor DarkCyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "$bar`n" -ForegroundColor DarkCyan
}

# ─── Deploy to Processor ──────────────────────────────────────────────────────

if (-not $SkipDeploy) {
    Write-Banner "Step 1/2 — Deploy to Processor ($ProcessorIp slot $Slot)"
    & "$PSScriptRoot\deploy-processor.ps1" `
        -ProcessorIp $ProcessorIp `
        -Slot        $Slot `
        -Username    $Username `
        -Password    $Password
}

# ─── Start Mobile Control UI ─────────────────────────────────────────────────

if (-not $SkipUi) {
    Write-Banner "Step 2/2 — Start Mobile Control UI"

    $uiDir = Join-Path $root 'mobile-control-ui'
    if (-not (Test-Path (Join-Path $uiDir 'node_modules'))) {
        Write-Host "==> Running npm install..." -ForegroundColor Cyan
        Push-Location $uiDir
        try {
            npm install
            if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
        } finally {
            Pop-Location
        }
    }

    Write-Host "    Starting React dev server in new window..."
    Write-Host "    UI will be available at: http://localhost:5173/mc/app?token=<value>" -ForegroundColor DarkGray
    Write-Host "    Get your token from the processor console: mobileinfo:$Slot" -ForegroundColor DarkGray

    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$uiDir'; npm run dev"
}

# ─── Summary ─────────────────────────────────────────────────────────────────

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host   "║  Deployment complete                                     ║" -ForegroundColor Green
Write-Host   "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
if (-not $SkipDeploy) {
    Write-Host "  Processor : $ProcessorIp  (slot $Slot)"
}
if (-not $SkipUi) {
    Write-Host "  UI        : http://localhost:5173"
}
Write-Host ""
Write-Host "To connect the UI to the processor:"
Write-Host "  1. Get token from processor console: MOBILEADDUICLIENT ?" -ForegroundColor DarkGray
Write-Host "  2. Browse to: http://localhost:5173/mc/app?token=<value>" -ForegroundColor DarkGray
