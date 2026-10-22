<#
.SYNOPSIS
    Remediation detection script template.

.DESCRIPTION
    Exit 0 = compliant, nothing to do.
    Exit 1 = issue found, Intune runs the remediation script.

    The last line written to STDOUT appears in the Remediations report as the
    detection output, so make it short and useful (it is truncated around 2048
    characters).

    Example below: ensure a registry value is set. Replace the CONFIG block.
    Settings in Intune: run as SYSTEM, 64-bit PowerShell = Yes, signature check as per policy.
#>

# ===== CONFIG =====
$RegPath   = 'HKLM:\SOFTWARE\Policies\Example\App'
$ValueName = 'DisableTelemetry'
$Expected  = 1
# ==================

try {
    if (-not (Test-Path -Path $RegPath)) {
        Write-Output "NonCompliant: key missing $RegPath"
        exit 1
    }

    $current = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty $ValueName -ErrorAction SilentlyContinue

    if ($null -eq $current) {
        Write-Output "NonCompliant: $ValueName not set"
        exit 1
    }

    if ($current -ne $Expected) {
        Write-Output "NonCompliant: $ValueName is $current, expected $Expected"
        exit 1
    }

    Write-Output "Compliant: $ValueName = $current"
    exit 0
}
catch {
    Write-Output "Error during detection: $($_.Exception.Message)"
    exit 1
}
