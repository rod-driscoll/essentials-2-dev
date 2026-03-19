<#
.SYNOPSIS
    Deploy PepperDash Essentials to a Crestron 4-series processor.

.DESCRIPTION
    Uploads the pre-built Essentials CPZ and the configurationFile.json to the
    processor via SFTP, then loads the program via SSH.

    Deployment steps:
      1. SFTP the CPZ to the processor's program slot directory (/program{slot}/).
      2. SFTP configurationFile.json to the slot's user directory (/User/Program{slot}/).
      3. SSH to the processor and run 'progload' to activate the program slot.

    The processor must have SSH/SFTP enabled (on by default on 4-series processors).
    Default credentials are admin / [blank password] on most 4-series processors.

    Requires the Posh-SSH PowerShell module (auto-installed if missing).

.PARAMETER ProcessorIp
    IP address or hostname of the Crestron processor. Mandatory.

.PARAMETER Slot
    Program slot number (1-10). Default: 1.

.PARAMETER Username
    SFTP/SSH username. Default: admin.

.PARAMETER Password
    SFTP/SSH password. Default: blank (empty string).

.PARAMETER CpzPath
    Path to the .cpz file to deploy. Defaults to the newest .cpz found in releases/.

.PARAMETER ConfigPath
    Path to the configurationFile.json to deploy. Default: <repo-root>\config\configurationFile.json.

.PARAMETER SkipConfig
    Skip uploading the configurationFile.json.

.PARAMETER ConfigOnly
    Upload the configurationFile.json only — skip the CPZ upload and progload.
    Useful for iterating on config without reloading the program.

.EXAMPLE
    .\scripts\deploy-processor.ps1 -ProcessorIp 192.168.104.171
    Deploy the latest CPZ and config to slot 1.

.EXAMPLE
    .\scripts\deploy-processor.ps1 -ProcessorIp 192.168.104.171 -ConfigOnly
    Upload configurationFile.json only (no CPZ, no progload).

.EXAMPLE
    .\scripts\deploy-processor.ps1 -ProcessorIp 192.168.104.171 -Slot 2 -SkipConfig
    Deploy CPZ only to slot 2.

.EXAMPLE
    .\scripts\deploy-processor.ps1 -ProcessorIp 192.168.104.171 -Username admin -Password mypass
    Deploy using non-default credentials.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $ProcessorIp,

    [ValidateRange(1, 10)]
    [int]    $Slot       = 1,

    [string] $Username   = 'admin',
    [string] $Password   = '',

    [string] $CpzPath,
    [string] $ConfigPath,

    [switch] $SkipConfig,
    [switch] $ConfigOnly
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function Write-Step([string] $msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Write-Success([string] $msg) {
    Write-Host "    OK  $msg" -ForegroundColor Green
}

# ─── Resolve CPZ path ─────────────────────────────────────────────────────────

if (-not $ConfigOnly) {
    if (-not $CpzPath) {
        $releasesDir = Join-Path $root 'releases'
        $cpzFiles = Get-ChildItem -Path $releasesDir -Filter '*.cpz' -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending
        if (-not $cpzFiles) {
            throw "No .cpz found in $releasesDir. Run .\scripts\get-release.ps1 first."
        }
        $CpzPath = $cpzFiles[0].FullName
        if ($cpzFiles.Count -gt 1) {
            Write-Host "    Multiple CPZs found — using newest: $($cpzFiles[0].Name)" -ForegroundColor Yellow
        }
    }

    if (-not (Test-Path $CpzPath)) {
        throw "CPZ not found: $CpzPath"
    }
}

# ─── Resolve config path ──────────────────────────────────────────────────────

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $root 'config\configurationFile.json'
}

if (-not $SkipConfig -and -not (Test-Path $ConfigPath)) {
    throw "configurationFile.json not found: $ConfigPath"
}

# ─── Resolve plugin CPLZ files ────────────────────────────────────────────────

$releasesDir  = Join-Path $root 'releases'
$cplzFiles    = Get-ChildItem -Path $releasesDir -Filter '*.cplz' -ErrorAction SilentlyContinue

# ─── Summary ──────────────────────────────────────────────────────────────────

Write-Step "Files to deploy:"
if (-not $ConfigOnly) {
    Write-Host "    CPZ    : $(Split-Path $CpzPath -Leaf)"
}
if (-not $SkipConfig) {
    Write-Host "    Config : $(Split-Path $ConfigPath -Leaf)"
}
if ($cplzFiles) {
    $cplzFiles | ForEach-Object { Write-Host "    Plugin : $($_.Name)" }
}

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

# ─── Upload CPZ to program slot directory ─────────────────────────────────────

$slotPadded  = $Slot.ToString('D2')
$remoteProg  = "/program$slotPadded"

if (-not $ConfigOnly) {
    $cpzName = Split-Path $CpzPath -Leaf
    Write-Step "Uploading $cpzName to sftp://$ProcessorIp$remoteProg/ ..."

    if ($PSCmdlet.ShouldProcess("$ProcessorIp$remoteProg/$cpzName", 'SFTP upload')) {
        $sftpSession = New-SFTPSession -ComputerName $ProcessorIp -Credential $credential -AcceptKey -Force
        try {
            Set-SFTPItem -SessionId $sftpSession.SessionId -Path $CpzPath -Destination $remoteProg -Force
            Write-Success $cpzName
        } finally {
            Remove-SFTPSession -SessionId $sftpSession.SessionId | Out-Null
        }
    }
}

# ─── Upload configurationFile.json to program user directory ──────────────────

if (-not $SkipConfig) {
    $configName   = Split-Path $ConfigPath -Leaf
    $remoteConfig = "/user/program$Slot"

    Write-Step "Uploading $configName to sftp://$ProcessorIp$remoteConfig/ ..."

    if ($PSCmdlet.ShouldProcess("$ProcessorIp$remoteConfig/$configName", 'SFTP upload')) {
        $sftpSession = New-SFTPSession -ComputerName $ProcessorIp -Credential $credential -AcceptKey -Force
        try {
            if (-not (Test-SFTPPath -SessionId $sftpSession.SessionId -Path $remoteConfig)) {
                Write-Host "    Creating remote directory $remoteConfig ..."
                $sftpSession.Session.CreateDirectory($remoteConfig)
            }
            Set-SFTPItem -SessionId $sftpSession.SessionId -Path $ConfigPath -Destination $remoteConfig -Force
            Write-Success $configName
        } finally {
            Remove-SFTPSession -SessionId $sftpSession.SessionId | Out-Null
        }
    }
}

# ─── Upload plugin CPLZ files to program user directory ──────────────────────

if ($cplzFiles) {
    $remotePlugins = "/user/program$Slot/plugins"
    foreach ($cplz in $cplzFiles) {
        Write-Step "Uploading plugin $($cplz.Name) to sftp://$ProcessorIp$remotePlugins/ ..."
        if ($PSCmdlet.ShouldProcess("$ProcessorIp$remotePlugins/$($cplz.Name)", 'SFTP upload')) {
            $sftpSession = New-SFTPSession -ComputerName $ProcessorIp -Credential $credential -AcceptKey -Force
            try {
                if (-not (Test-SFTPPath -SessionId $sftpSession.SessionId -Path $remotePlugins)) {
                    Write-Host "    Creating remote directory $remotePlugins ..."
                    $sftpSession.Session.CreateDirectory($remotePlugins)
                }
                Set-SFTPItem -SessionId $sftpSession.SessionId -Path $cplz.FullName -Destination $remotePlugins -Force
                Write-Success $cplz.Name
            } finally {
                Remove-SFTPSession -SessionId $sftpSession.SessionId | Out-Null
            }
        }
    }
}

# ─── Load program via SSH ─────────────────────────────────────────────────────

if (-not $ConfigOnly) {
    $loadCommand = "progload -p:$slotPadded $cpzName"
    Write-Step "Loading program slot $Slot on $ProcessorIp ..."
    Write-Host "    SSH command: $loadCommand"

    if ($PSCmdlet.ShouldProcess("$ProcessorIp:22", "SSH progload slot $Slot")) {
        $sshSession = New-SSHSession -ComputerName $ProcessorIp -Credential $credential -AcceptKey -Force
        try {
            $result = Invoke-SSHCommand -SessionId $sshSession.SessionId -Command $loadCommand
            if ($result.ExitStatus -eq 0) {
                Write-Success "progload complete."
            } else {
                Write-Warning "progload returned exit code $($result.ExitStatus) — check the processor console."
            }
        } finally {
            Remove-SSHSession -SessionId $sshSession.SessionId | Out-Null
        }
    }
}

Write-Host "`nDeploy to processor complete." -ForegroundColor Green
Write-Host "  Processor : $ProcessorIp"
Write-Host "  Slot      : $Slot"
if (-not $ConfigOnly) {
    Write-Host "  CPZ       : $cpzName"
}
if (-not $SkipConfig) {
    Write-Host "  Config    : $(Split-Path $ConfigPath -Leaf)"
}
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Get a mobile control token from the processor console:"
Write-Host "       MOBILEADDUICLIENT ?" -ForegroundColor DarkGray
Write-Host "  2. Start the mobile UI dev server:"
Write-Host "       npm run dev" -ForegroundColor DarkGray
Write-Host "  3. Open in browser:"
Write-Host "       http://localhost:5173/mc/app?token=<value>" -ForegroundColor DarkGray
