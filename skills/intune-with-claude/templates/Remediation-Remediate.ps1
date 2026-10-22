<#
.SYNOPSIS
    Remediation script template. Pairs with Remediation-Detect.ps1.

.DESCRIPTION
    Fix the issue the detection script found, log what happened, and exit 0 on
    success or 1 on failure. Intune re-runs the detection script afterwards to
    confirm the fix.

    Logs to C:\ProgramData\IntuneScripts\Logs so there is local evidence.
#>

# ===== CONFIG =====
$RegPath    = 'HKLM:\SOFTWARE\Policies\Example\App'
$ValueName  = 'DisableTelemetry'
$Value      = 1
$ValueType  = 'DWord'
$ScriptName = 'Remediate-ExampleAppTelemetry'
# ==================

$LogDir  = Join-Path $env:ProgramData 'IntuneScripts\Logs'
$LogFile = Join-Path $LogDir "$ScriptName.log"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

try {
    Write-Log "Starting remediation"

    if (-not (Test-Path -Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
        Write-Log "Created key $RegPath"
    }

    New-ItemProperty -Path $RegPath -Name $ValueName -Value $Value -PropertyType $ValueType -Force | Out-Null
    Write-Log "Set $ValueName to $Value"

    Write-Output "Remediated: $ValueName set to $Value"
    exit 0
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    Write-Output "Remediation failed: $($_.Exception.Message)"
    exit 1
}
