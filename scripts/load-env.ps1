<#
.SYNOPSIS
    Loads deployment settings from a .env file.

.DESCRIPTION
    Reads KEY=VALUE pairs from a .env file and returns them as a hashtable.
    Lines starting with # and blank lines are ignored. Inline comments are not supported.
    Call this with dot-sourcing, then use Read-EnvFile to get the values.

.EXAMPLE
    . "$PSScriptRoot/load-env.ps1"
    $cfg = Read-EnvFile (Join-Path $root '.env')
    $ip  = $cfg['PROCESSOR_IP']
#>

function Read-EnvFile {
    param(
        [string] $Path
    )

    $result = @{}

    if (-not (Test-Path $Path)) {
        return $result
    }

    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -and $line -notmatch '^\s*#' -and $line -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') {
            $result[$Matches[1]] = $Matches[2]
        }
    }

    return $result
}

function Resolve-EnvParam {
    <#
    .SYNOPSIS
        Returns the env value if the script parameter was not explicitly passed.
    #>
    param(
        [hashtable] $BoundParams,
        [string]    $ParamName,
        [object]    $CurrentValue,
        [hashtable] $Env,
        [string]    $EnvKey
    )

    if (-not $BoundParams.ContainsKey($ParamName) -and $Env.ContainsKey($EnvKey) -and $Env[$EnvKey]) {
        return $Env[$EnvKey]
    }
    return $CurrentValue
}
