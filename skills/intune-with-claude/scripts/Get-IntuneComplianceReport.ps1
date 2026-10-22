#Requires -Version 5.1
<#
.SYNOPSIS
    Exports device compliance state for all Intune managed devices (read-only).

.DESCRIPTION
    One row per managed device with compliance state, OS, version, ownership, primary
    user, last sync, encryption and Autopilot enrollment flag. Prints a summary by
    compliance state and OS.

.PARAMETER OutputCsv
    Path to write the CSV.

.PARAMETER OperatingSystem
    Optional filter: Windows, iOS, Android, macOS.

.PARAMETER NonCompliantOnly
    Only output devices that are not compliant.

.EXAMPLE
    .\Get-IntuneComplianceReport.ps1 -OperatingSystem Windows -NonCompliantOnly

.NOTES
    Scope used: DeviceManagementManagedDevices.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (Join-Path (Get-Location) ("IntuneCompliance-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))),
    [ValidateSet('Windows', 'iOS', 'Android', 'macOS')]
    [string]$OperatingSystem,
    [switch]$NonCompliantOnly,
    [string]$TenantId
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\IntuneGraph.Common.ps1"

$connectParams = @{ Scopes = @('DeviceManagementManagedDevices.Read.All') }
if ($TenantId) { $connectParams.TenantId = $TenantId }
Connect-IntuneGraph @connectParams

$select = 'id,deviceName,complianceState,operatingSystem,osVersion,managedDeviceOwnerType,userPrincipalName,lastSyncDateTime,isEncrypted,serialNumber,model,manufacturer,autopilotEnrolled,joinType,enrolledDateTime'
$uri = "v1.0/deviceManagement/managedDevices?`$select=$select"
if ($OperatingSystem) {
    $uri += "&`$filter=operatingSystem eq '$OperatingSystem'"
}

Write-Host "Reading managed devices..."
try {
    $devices = Invoke-IntuneGraphPaged -Uri $uri
}
catch {
    Write-Verbose "v1.0 select failed (some properties are beta only). Retrying on beta."
    $devices = Invoke-IntuneGraphPaged -Uri ($uri -replace '^v1.0', 'beta')
}

$now = Get-Date
$rows = foreach ($d in $devices) {
    $lastSync = $null
    if ($d.lastSyncDateTime) { $lastSync = [datetime]$d.lastSyncDateTime }
    [pscustomobject]@{
        DeviceName        = $d.deviceName
        ComplianceState   = $d.complianceState
        OperatingSystem   = $d.operatingSystem
        OSVersion         = $d.osVersion
        Ownership         = $d.managedDeviceOwnerType
        PrimaryUser       = $d.userPrincipalName
        LastSync          = $lastSync
        DaysSinceSync     = if ($lastSync) { [int]($now - $lastSync).TotalDays } else { $null }
        Encrypted         = $d.isEncrypted
        AutopilotEnrolled = $d.autopilotEnrolled
        JoinType          = $d.joinType
        Manufacturer      = $d.manufacturer
        Model             = $d.model
        SerialNumber      = $d.serialNumber
        Enrolled          = $d.enrolledDateTime
        IntuneDeviceId    = $d.id
    }
}

if ($NonCompliantOnly) {
    $rows = $rows | Where-Object { $_.ComplianceState -ne 'compliant' }
}

$rows | Sort-Object ComplianceState, DeviceName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Summary by compliance state:"
$rows | Group-Object ComplianceState | Sort-Object Count -Descending |
    Format-Table @{ n = 'State'; e = { $_.Name } }, Count -AutoSize

Write-Host "Summary by OS:"
$rows | Group-Object OperatingSystem | Sort-Object Count -Descending |
    Format-Table @{ n = 'OS'; e = { $_.Name } }, Count -AutoSize

Write-Host ("{0} device(s) written to {1}" -f @($rows).Count, $OutputCsv) -ForegroundColor Green
