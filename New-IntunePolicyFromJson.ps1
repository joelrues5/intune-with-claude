#Requires -Version 5.1
<#
.SYNOPSIS
    Creates an Intune settings catalog or compliance policy from a JSON file, and
    optionally assigns it to a group.

.DESCRIPTION
    Accepts JSON from a template in this skill, a body Claude generated, or an export
    from Export-IntuneConfig.ps1 (read-only properties are stripped automatically,
    and existing assignments in the file are ignored).

    Policy type is detected from the JSON:
      - Has "settings" and "platforms"            -> settings catalog (configurationPolicies)
      - @odata.type ends with "CompliancePolicy"  -> compliance policy

    Supports -WhatIf: shows the endpoint and cleaned body without creating anything.

.PARAMETER Path
    Path to the JSON file.

.PARAMETER Name
    Optional. Overrides the name/displayName in the file.

.PARAMETER AssignGroupId
    Optional. Entra group object ID to assign the policy to (include).

.PARAMETER ExcludeGroupId
    Optional. Entra group object ID to exclude.

.EXAMPLE
    .\New-IntunePolicyFromJson.ps1 -Path ..\templates\compliance-windows-baseline.json -WhatIf

.EXAMPLE
    .\New-IntunePolicyFromJson.ps1 -Path .\WIN-SC-PILOT-Edge-v1.json -AssignGroupId <GROUP-OBJECT-ID>

.NOTES
    Scopes used: DeviceManagementConfiguration.ReadWrite.All, Group.Read.All
    Settings catalog endpoints are Graph beta.
    Always assign new policies to a pilot group first.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$Path,

    [string]$Name,

    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$AssignGroupId,

    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$ExcludeGroupId,

    [string]$TenantId
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\IntuneGraph.Common.ps1"

$raw = Get-Content -Path $Path -Raw -Encoding UTF8
$policy = $raw | ConvertFrom-Json

$readOnly = @('id', 'createdDateTime', 'lastModifiedDateTime', 'version', 'settingCount',
    'assignments', 'isAssigned', 'creationSource', 'priorityMetaData', '@odata.context',
    'settings@odata.context', 'assignments@odata.context', 'scheduledActionsForRule@odata.context')

foreach ($prop in $readOnly) {
    if ($policy.PSObject.Properties.Name -contains $prop) {
        $policy.PSObject.Properties.Remove($prop)
    }
}

$odataType = [string]$policy.'@odata.type'
$isSettingsCatalog = ($policy.PSObject.Properties.Name -contains 'settings') -and ($policy.PSObject.Properties.Name -contains 'platforms')
$isCompliance = $odataType -like '*CompliancePolicy'

if ($isSettingsCatalog) {
    $kind = 'Settings catalog'
    $endpoint = 'beta/deviceManagement/configurationPolicies'
    if ($Name) { $policy.name = $Name }
    $displayName = $policy.name

    # Settings from an export carry ids; the create call only needs settingInstance.
    $cleanSettings = foreach ($s in $policy.settings) {
        [pscustomobject]@{
            '@odata.type'   = '#microsoft.graph.deviceManagementConfigurationSetting'
            settingInstance = $s.settingInstance
        }
    }
    $policy.settings = @($cleanSettings)
}
elseif ($isCompliance) {
    $kind = 'Compliance policy'
    $endpoint = 'beta/deviceManagement/deviceCompliancePolicies'
    if ($Name) { $policy.displayName = $Name }
    $displayName = $policy.displayName

    if (-not $policy.scheduledActionsForRule) {
        Write-Verbose "No scheduledActionsForRule found. Adding default: mark noncompliant immediately."
        $policy | Add-Member -NotePropertyName scheduledActionsForRule -Force -NotePropertyValue @(
            [pscustomobject]@{
                ruleName                      = 'PasswordRequired'
                scheduledActionConfigurations = @(
                    [pscustomobject]@{ actionType = 'block'; gracePeriodHours = 0; notificationTemplateId = ''; notificationMessageCCList = @() }
                )
            }
        )
    }
    else {
        foreach ($rule in $policy.scheduledActionsForRule) {
            foreach ($p in @('id', 'scheduledActionConfigurations@odata.context')) {
                if ($rule.PSObject.Properties.Name -contains $p) { $rule.PSObject.Properties.Remove($p) }
            }
            foreach ($cfg in $rule.scheduledActionConfigurations) {
                if ($cfg.PSObject.Properties.Name -contains 'id') { $cfg.PSObject.Properties.Remove('id') }
            }
        }
    }
}
else {
    throw "Could not detect policy type. Expected a settings catalog body (settings + platforms) or a compliance policy (@odata.type ending in CompliancePolicy)."
}

$body = $policy | ConvertTo-Json -Depth 50

if (-not $PSCmdlet.ShouldProcess("$kind '$displayName'", "Create via POST $endpoint")) {
    Write-Host "Endpoint: POST https://graph.microsoft.com/$endpoint"
    Write-Host $body
    if ($AssignGroupId -or $ExcludeGroupId) {
        Write-Host "Would assign: include $AssignGroupId exclude $ExcludeGroupId"
    }
    return
}

$connectParams = @{ Scopes = @('DeviceManagementConfiguration.ReadWrite.All', 'Group.Read.All') }
if ($TenantId) { $connectParams.TenantId = $TenantId }
Connect-IntuneGraph @connectParams

$created = Invoke-IntuneGraph -Method POST -Uri $endpoint -Body $body
Write-Host ("Created {0} '{1}' with id {2}" -f $kind, $displayName, $created.id) -ForegroundColor Green

if ($AssignGroupId -or $ExcludeGroupId) {
    $assignments = New-Object System.Collections.Generic.List[object]
    if ($AssignGroupId) {
        $assignments.Add(@{ target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $AssignGroupId } })
    }
    if ($ExcludeGroupId) {
        $assignments.Add(@{ target = @{ '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'; groupId = $ExcludeGroupId } })
    }
    if ($isCompliance) {
        foreach ($a in $assignments) { $a['@odata.type'] = '#microsoft.graph.deviceCompliancePolicyAssignment' }
    }

    $assignBody = @{ assignments = $assignments } | ConvertTo-Json -Depth 10
    Invoke-IntuneGraph -Method POST -Uri "$endpoint/$($created.id)/assign" -Body $assignBody | Out-Null

    $inc = if ($AssignGroupId) { Get-IntuneGroupName -GroupId $AssignGroupId } else { '-' }
    $exc = if ($ExcludeGroupId) { Get-IntuneGroupName -GroupId $ExcludeGroupId } else { '-' }
    Write-Host ("Assigned. Include: {0}  Exclude: {1}" -f $inc, $exc) -ForegroundColor Green
}
else {
    Write-Host "Not assigned. Assign to a pilot group before production." -ForegroundColor Yellow
}
