#Requires -Version 5.1
<#
.SYNOPSIS
    Backs up Intune configuration to JSON files (read-only).

.DESCRIPTION
    Exports settings catalog and endpoint security policies (with settings), legacy
    device configurations, administrative templates (ADMX) with values, compliance
    policies, platform scripts, remediations, app metadata, app protection policies,
    assignment filters, Autopilot profiles and enrollment configurations.

    Each object is written to <OutputPath>\<Category>\<Name>__<Id>.json including its
    assignments, so the export can be committed to Git and diffed over time.

    Script content for platform scripts and remediations is decoded and saved next to
    the JSON as .ps1 files for easy review.

.PARAMETER OutputPath
    Folder to write the export to. A timestamped subfolder is created.

.PARAMETER TenantId
    Optional tenant ID or domain to connect to.

.PARAMETER Category
    Limit the export to specific categories. Default is all.

.EXAMPLE
    .\Export-IntuneConfig.ps1 -OutputPath C:\IntuneBackup

.EXAMPLE
    .\Export-IntuneConfig.ps1 -OutputPath .\backup -Category SettingsCatalog,Compliance

.NOTES
    Scopes used: DeviceManagementConfiguration.Read.All, DeviceManagementApps.Read.All,
    DeviceManagementServiceConfig.Read.All, Group.Read.All
    Most endpoints are Graph beta and can change.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputPath,

    [string]$TenantId,

    [ValidateSet('SettingsCatalog', 'DeviceConfigurations', 'AdminTemplates', 'Compliance',
        'PlatformScripts', 'Remediations', 'Apps', 'AppProtection', 'Filters',
        'Autopilot', 'Enrollment')]
    [string[]]$Category = @('SettingsCatalog', 'DeviceConfigurations', 'AdminTemplates', 'Compliance',
        'PlatformScripts', 'Remediations', 'Apps', 'AppProtection', 'Filters', 'Autopilot', 'Enrollment')
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\IntuneGraph.Common.ps1"

$scopes = @(
    'DeviceManagementConfiguration.Read.All',
    'DeviceManagementApps.Read.All',
    'DeviceManagementServiceConfig.Read.All',
    'Group.Read.All'
)
$connectParams = @{ Scopes = $scopes }
if ($TenantId) { $connectParams.TenantId = $TenantId }
Connect-IntuneGraph @connectParams

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = Join-Path $OutputPath "IntuneExport-$stamp"
New-Item -ItemType Directory -Path $root -Force | Out-Null

function Save-IntuneObject {
    param(
        [string]$Folder,
        [object]$Object,
        [string]$NameProperty = 'displayName'
    )
    $dir = Join-Path $root $Folder
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $name = $Object.$NameProperty
    if (-not $name) { $name = $Object.name }
    if (-not $name) { $name = 'unnamed' }
    $file = Join-Path $dir ("{0}__{1}.json" -f (ConvertTo-SafeFileName $name), $Object.id)
    $Object | ConvertTo-Json -Depth 50 | Out-File -FilePath $file -Encoding utf8
    return $file
}

function Save-ScriptContent {
    param([string]$JsonFile, [string]$Suffix, [string]$Base64)
    if (-not $Base64) { return }
    try {
        $text = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Base64))
        $ps1 = [System.IO.Path]::ChangeExtension($JsonFile, $null).TrimEnd('.') + $Suffix
        $text | Out-File -FilePath $ps1 -Encoding utf8
    }
    catch {
        Write-Warning "Could not decode script content for $JsonFile"
    }
}

function Export-Collection {
    param(
        [string]$Label,
        [string]$Folder,
        [string]$ListUri,
        [scriptblock]$Detail,
        [string]$NameProperty = 'displayName'
    )
    Write-Host "Exporting $Label..."
    $items = Invoke-IntuneGraphPaged -Uri $ListUri
    $count = 0
    foreach ($item in $items) {
        if ($Detail) { $item = & $Detail $item }
        $null = Save-IntuneObject -Folder $Folder -Object $item -NameProperty $NameProperty
        $count++
    }
    Write-Host ("  {0} item(s)" -f $count)
}

$summary = [ordered]@{}

if ($Category -contains 'SettingsCatalog') {
    Export-Collection -Label 'settings catalog and endpoint security policies' -Folder 'SettingsCatalog' `
        -ListUri 'beta/deviceManagement/configurationPolicies' -NameProperty 'name' -Detail {
        param($p)
        $full = Invoke-IntuneGraph -Uri "beta/deviceManagement/configurationPolicies/$($p.id)?`$expand=settings,assignments"
        return $full
    }
}

if ($Category -contains 'DeviceConfigurations') {
    Export-Collection -Label 'device configurations (templates)' -Folder 'DeviceConfigurations' `
        -ListUri 'beta/deviceManagement/deviceConfigurations?$expand=assignments'
}

if ($Category -contains 'AdminTemplates') {
    Export-Collection -Label 'administrative templates (ADMX)' -Folder 'AdminTemplates' `
        -ListUri 'beta/deviceManagement/groupPolicyConfigurations?$expand=assignments' -Detail {
        param($p)
        $values = Invoke-IntuneGraphPaged -Uri "beta/deviceManagement/groupPolicyConfigurations/$($p.id)/definitionValues?`$expand=definition(`$select=displayName,classType,categoryPath),presentationValues"
        $p | Add-Member -NotePropertyName definitionValues -NotePropertyValue $values -Force
        return $p
    }
}

if ($Category -contains 'Compliance') {
    Export-Collection -Label 'compliance policies' -Folder 'Compliance' `
        -ListUri 'beta/deviceManagement/deviceCompliancePolicies?$expand=assignments,scheduledActionsForRule($expand=scheduledActionConfigurations)'

    Write-Host "Exporting compliance scripts..."
    $scripts = Invoke-IntuneGraphPaged -Uri 'beta/deviceManagement/deviceComplianceScripts'
    foreach ($s in $scripts) {
        $full = Invoke-IntuneGraph -Uri "beta/deviceManagement/deviceComplianceScripts/$($s.id)"
        $file = Save-IntuneObject -Folder 'ComplianceScripts' -Object $full
        Save-ScriptContent -JsonFile $file -Suffix '.ps1' -Base64 $full.detectionScriptContent
    }
    Write-Host ("  {0} item(s)" -f @($scripts).Count)
}

if ($Category -contains 'PlatformScripts') {
    Write-Host "Exporting platform scripts..."
    $scripts = Invoke-IntuneGraphPaged -Uri 'beta/deviceManagement/deviceManagementScripts'
    foreach ($s in $scripts) {
        $full = Invoke-IntuneGraph -Uri "beta/deviceManagement/deviceManagementScripts/$($s.id)?`$expand=assignments"
        $file = Save-IntuneObject -Folder 'PlatformScripts' -Object $full
        Save-ScriptContent -JsonFile $file -Suffix '.ps1' -Base64 $full.scriptContent
    }
    Write-Host ("  {0} item(s)" -f @($scripts).Count)
}

if ($Category -contains 'Remediations') {
    Write-Host "Exporting remediations..."
    $scripts = Invoke-IntuneGraphPaged -Uri 'beta/deviceManagement/deviceHealthScripts'
    foreach ($s in $scripts) {
        if ($s.publisher -eq 'Microsoft') { continue }
        $full = Invoke-IntuneGraph -Uri "beta/deviceManagement/deviceHealthScripts/$($s.id)?`$expand=assignments"
        $file = Save-IntuneObject -Folder 'Remediations' -Object $full
        Save-ScriptContent -JsonFile $file -Suffix '.detect.ps1' -Base64 $full.detectionScriptContent
        Save-ScriptContent -JsonFile $file -Suffix '.remediate.ps1' -Base64 $full.remediationScriptContent
    }
    Write-Host ("  {0} item(s)" -f @($scripts).Count)
}

if ($Category -contains 'Apps') {
    Export-Collection -Label 'apps (metadata only, no binaries)' -Folder 'Apps' `
        -ListUri 'beta/deviceAppManagement/mobileApps?$expand=assignments'
}

if ($Category -contains 'AppProtection') {
    Export-Collection -Label 'iOS app protection' -Folder 'AppProtection-iOS' `
        -ListUri 'beta/deviceAppManagement/iosManagedAppProtections?$expand=apps,assignments'
    Export-Collection -Label 'Android app protection' -Folder 'AppProtection-Android' `
        -ListUri 'beta/deviceAppManagement/androidManagedAppProtections?$expand=apps,assignments'
    Export-Collection -Label 'app configuration (managed devices)' -Folder 'AppConfiguration' `
        -ListUri 'beta/deviceAppManagement/mobileAppConfigurations?$expand=assignments'
}

if ($Category -contains 'Filters') {
    Export-Collection -Label 'assignment filters' -Folder 'AssignmentFilters' `
        -ListUri 'beta/deviceManagement/assignmentFilters'
}

if ($Category -contains 'Autopilot') {
    Export-Collection -Label 'Autopilot deployment profiles' -Folder 'Autopilot' `
        -ListUri 'beta/deviceManagement/windowsAutopilotDeploymentProfiles?$expand=assignments'
}

if ($Category -contains 'Enrollment') {
    Export-Collection -Label 'enrollment configurations (ESP, restrictions)' -Folder 'Enrollment' `
        -ListUri 'beta/deviceManagement/deviceEnrollmentConfigurations?$expand=assignments'
}

Write-Host ""
Write-Host "Export complete: $root" -ForegroundColor Green
Write-Host "Tip: commit this folder to a private Git repo to track changes between exports."
