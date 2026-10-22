#Requires -Version 5.1
<#
.SYNOPSIS
    Reports Intune managed devices that have not synced in N days. Report-only by default.

.DESCRIPTION
    Lists stale devices to CSV. With -Action Retire or -Action Delete it will act on
    them, but only after showing the list and requiring you to type the exact device
    count to confirm. -WhatIf is supported.

    Delete removes the Intune record only. It does not remove the Entra device object
    or the Autopilot registration.

.PARAMETER Days
    Devices whose last sync is older than this many days are stale. Default 90.

.PARAMETER Action
    Report (default), Retire or Delete.

.EXAMPLE
    .\Get-IntuneStaleDevices.ps1 -Days 120

.EXAMPLE
    .\Get-IntuneStaleDevices.ps1 -Days 180 -Action Delete -WhatIf

.NOTES
    Report scope: DeviceManagementManagedDevices.Read.All
    Retire/Delete scopes: DeviceManagementManagedDevices.ReadWrite.All,
    DeviceManagementManagedDevices.PrivilegedOperations.All
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateRange(7, 3650)]
    [int]$Days = 90,

    [ValidateSet('Report', 'Retire', 'Delete')]
    [string]$Action = 'Report',

    [string]$OutputCsv = (Join-Path (Get-Location) ("IntuneStaleDevices-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))),

    [string]$TenantId
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\IntuneGraph.Common.ps1"

$scopes = @('DeviceManagementManagedDevices.Read.All')
if ($Action -ne 'Report') {
    $scopes = @('DeviceManagementManagedDevices.ReadWrite.All', 'DeviceManagementManagedDevices.PrivilegedOperations.All')
}
$connectParams = @{ Scopes = $scopes }
if ($TenantId) { $connectParams.TenantId = $TenantId }
Connect-IntuneGraph @connectParams

$cutoff = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
$uri = "v1.0/deviceManagement/managedDevices?`$filter=lastSyncDateTime le $cutoff&`$select=id,deviceName,operatingSystem,osVersion,userPrincipalName,lastSyncDateTime,managedDeviceOwnerType,serialNumber"

Write-Host "Finding devices with no sync since $cutoff..."
$stale = @(Invoke-IntuneGraphPaged -Uri $uri)

$stale | Select-Object deviceName, operatingSystem, osVersion, userPrincipalName, lastSyncDateTime, managedDeviceOwnerType, serialNumber, id |
    Sort-Object lastSyncDateTime |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ("{0} stale device(s) written to {1}" -f $stale.Count, $OutputCsv) -ForegroundColor Yellow
$stale | Group-Object operatingSystem | Format-Table @{ n = 'OS'; e = { $_.Name } }, Count -AutoSize

if ($Action -eq 'Report' -or $stale.Count -eq 0) { return }

Write-Warning ("About to {0} {1} device(s). Review {2} first." -f $Action.ToUpper(), $stale.Count, $OutputCsv)
if (-not $WhatIfPreference) {
    $typed = Read-Host ("Type the number of devices ({0}) to confirm, anything else to cancel" -f $stale.Count)
    if ($typed -ne [string]$stale.Count) {
        Write-Host "Cancelled. No changes made."
        return
    }
}

$done = 0
foreach ($d in $stale) {
    $label = "{0} ({1}, last sync {2})" -f $d.deviceName, $d.serialNumber, $d.lastSyncDateTime
    if ($PSCmdlet.ShouldProcess($label, $Action)) {
        try {
            if ($Action -eq 'Retire') {
                Invoke-IntuneGraph -Method POST -Uri "v1.0/deviceManagement/managedDevices/$($d.id)/retire" | Out-Null
            }
            else {
                Invoke-IntuneGraph -Method DELETE -Uri "v1.0/deviceManagement/managedDevices/$($d.id)" | Out-Null
            }
            $done++
        }
        catch {
            Write-Warning "Failed on ${label}: $($_.Exception.Message)"
        }
    }
}
Write-Host ("{0} of {1} device(s) processed with action {2}." -f $done, $stale.Count, $Action)
