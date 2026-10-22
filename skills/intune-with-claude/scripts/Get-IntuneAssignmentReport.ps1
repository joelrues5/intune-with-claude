#Requires -Version 5.1
<#
.SYNOPSIS
    Lists every Intune policy, script and app with its assignments (read-only).

.DESCRIPTION
    Produces one row per assignment target with the object type, name, intent (for
    apps), target group, include or exclude, and assignment filter name and mode.
    Unassigned objects are included with Target = "(not assigned)" so you can find
    orphaned policies.

.PARAMETER OutputCsv
    Path to write the CSV. Defaults to .\IntuneAssignments-<date>.csv

.PARAMETER GroupName
    Optional. Only return rows that target this group display name (wildcards allowed).

.EXAMPLE
    .\Get-IntuneAssignmentReport.ps1

.EXAMPLE
    .\Get-IntuneAssignmentReport.ps1 -GroupName 'INT-DEV-WIN-Pilot'

.NOTES
    Scopes used: DeviceManagementConfiguration.Read.All, DeviceManagementApps.Read.All,
    DeviceManagementServiceConfig.Read.All, Group.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (Join-Path (Get-Location) ("IntuneAssignments-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))),
    [string]$GroupName,
    [string]$TenantId
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\IntuneGraph.Common.ps1"

$connectParams = @{
    Scopes = @('DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All',
        'DeviceManagementServiceConfig.Read.All', 'Group.Read.All')
}
if ($TenantId) { $connectParams.TenantId = $TenantId }
Connect-IntuneGraph @connectParams

Write-Host "Loading assignment filters..."
$filterNames = @{}
foreach ($f in (Invoke-IntuneGraphPaged -Uri 'beta/deviceManagement/assignmentFilters')) {
    $filterNames[$f.id] = $f.displayName
}

$sources = @(
    @{ Type = 'Settings catalog / Endpoint security'; Uri = 'beta/deviceManagement/configurationPolicies?$expand=assignments'; Name = 'name' },
    @{ Type = 'Device configuration (template)'; Uri = 'beta/deviceManagement/deviceConfigurations?$expand=assignments'; Name = 'displayName' },
    @{ Type = 'Administrative template'; Uri = 'beta/deviceManagement/groupPolicyConfigurations?$expand=assignments'; Name = 'displayName' },
    @{ Type = 'Compliance policy'; Uri = 'beta/deviceManagement/deviceCompliancePolicies?$expand=assignments'; Name = 'displayName' },
    @{ Type = 'Platform script'; Uri = 'beta/deviceManagement/deviceManagementScripts?$expand=assignments'; Name = 'displayName' },
    @{ Type = 'Remediation'; Uri = 'beta/deviceManagement/deviceHealthScripts?$expand=assignments'; Name = 'displayName' },
    @{ Type = 'App'; Uri = 'beta/deviceAppManagement/mobileApps?$expand=assignments'; Name = 'displayName' },
    @{ Type = 'Autopilot profile'; Uri = 'beta/deviceManagement/windowsAutopilotDeploymentProfiles?$expand=assignments'; Name = 'displayName' },
    @{ Type = 'Enrollment configuration'; Uri = 'beta/deviceManagement/deviceEnrollmentConfigurations?$expand=assignments'; Name = 'displayName' }
)

$rows = New-Object System.Collections.Generic.List[object]

foreach ($src in $sources) {
    Write-Host "Reading $($src.Type)..."
    try {
        $items = Invoke-IntuneGraphPaged -Uri $src.Uri
    }
    catch {
        Write-Warning "Could not read $($src.Type): $($_.Exception.Message)"
        continue
    }

    foreach ($item in $items) {
        $name = $item.($src.Name)
        $odataType = ($item.'@odata.type' -replace '#microsoft.graph.', '')

        if (-not $item.assignments -or @($item.assignments).Count -eq 0) {
            $rows.Add([pscustomobject]@{
                    ObjectType = $src.Type
                    SubType    = $odataType
                    Name       = $name
                    Id         = $item.id
                    Intent     = ''
                    Mode       = ''
                    Target     = '(not assigned)'
                    FilterName = ''
                    FilterMode = ''
                })
            continue
        }

        foreach ($a in $item.assignments) {
            $t = $a.target
            $tType = $t.'@odata.type'
            switch -Wildcard ($tType) {
                '*exclusionGroupAssignmentTarget'   { $mode = 'Exclude'; $target = Get-IntuneGroupName -GroupId $t.groupId }
                '*groupAssignmentTarget'            { $mode = 'Include'; $target = Get-IntuneGroupName -GroupId $t.groupId }
                '*allDevicesAssignmentTarget'       { $mode = 'Include'; $target = 'All devices' }
                '*allLicensedUsersAssignmentTarget' { $mode = 'Include'; $target = 'All users' }
                default                             { $mode = ''; $target = $tType }
            }

            $filterId = $t.deviceAndAppManagementAssignmentFilterId
            $filterName = ''
            $filterMode = ''
            if ($filterId -and $filterId -ne '00000000-0000-0000-0000-000000000000') {
                $filterName = $filterNames[$filterId]
                if (-not $filterName) { $filterName = $filterId }
                $filterMode = $t.deviceAndAppManagementAssignmentFilterType
            }

            $rows.Add([pscustomobject]@{
                    ObjectType = $src.Type
                    SubType    = $odataType
                    Name       = $name
                    Id         = $item.id
                    Intent     = $a.intent
                    Mode       = $mode
                    Target     = $target
                    FilterName = $filterName
                    FilterMode = $filterMode
                })
        }
    }
}

if ($GroupName) {
    $rows = $rows | Where-Object { $_.Target -like $GroupName }
}

$rows | Sort-Object ObjectType, Name, Mode | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host ("{0} row(s) written to {1}" -f @($rows).Count, $OutputCsv) -ForegroundColor Green

$unassigned = @($rows | Where-Object { $_.Target -eq '(not assigned)' })
if ($unassigned.Count -gt 0) {
    Write-Host ("{0} object(s) have no assignments. Review them for clean-up." -f $unassigned.Count) -ForegroundColor Yellow
}
