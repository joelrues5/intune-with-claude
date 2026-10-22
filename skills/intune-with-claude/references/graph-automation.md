# Graph and PowerShell automation for Intune

## Tooling

- **Microsoft Graph PowerShell SDK:** `Install-Module Microsoft.Graph.Authentication -Scope CurrentUser`. Use `Invoke-MgGraphRequest` for Intune because most endpoints are beta and the generated cmdlets lag behind.
- **Do not use:** `Microsoft.Graph.Intune` (Intune PowerShell SDK), `AzureAD`, `MSOnline`. Retired or deprecated.
- **Community tools worth knowing:** IntuneManagement (Micke-K, GUI export/import/compare), IntuneCD (config as code, documentation), Microsoft365DSC (desired state and drift reports). Recommend them when the user wants backup, documentation or tenant-to-tenant copy at scale.

## Authentication patterns

| Use | Pattern |
|---|---|
| Ad hoc admin work | `Connect-MgGraph -Scopes <scopes> -TenantId <tenant>` (delegated, interactive) |
| Scheduled automation | App registration with certificate: `Connect-MgGraph -ClientId <appId> -TenantId <tenant> -CertificateThumbprint <thumb>` |
| Azure Automation / Functions | Managed identity: `Connect-MgGraph -Identity` and grant the MI app roles |

Never put client secrets in scripts. For MSP multi-tenant work use GDAP plus per-tenant delegated sign-in, or a multi-tenant app consented per customer.

## Scopes

| Area | Read | Write |
|---|---|---|
| Config, compliance, scripts, baselines | DeviceManagementConfiguration.Read.All | DeviceManagementConfiguration.ReadWrite.All |
| Managed devices | DeviceManagementManagedDevices.Read.All | DeviceManagementManagedDevices.ReadWrite.All; PrivilegedOperations.All for wipe/retire |
| Apps | DeviceManagementApps.Read.All | DeviceManagementApps.ReadWrite.All |
| Enrollment, Autopilot, connectors | DeviceManagementServiceConfig.Read.All | DeviceManagementServiceConfig.ReadWrite.All |
| RBAC, scope tags | DeviceManagementRBAC.Read.All | DeviceManagementRBAC.ReadWrite.All |
| Resolving group names | Group.Read.All | Group.ReadWrite.All |

Least privilege: default to Read scopes.

## Endpoint map (most are beta)

| Object | Endpoint |
|---|---|
| Settings catalog and newer endpoint security | `/beta/deviceManagement/configurationPolicies` (`?$expand=settings`, `/assignments`, `/assign`) |
| Templates (legacy device configuration) | `/beta/deviceManagement/deviceConfigurations` |
| Administrative templates (ADMX) | `/beta/deviceManagement/groupPolicyConfigurations` (values under `definitionValues`) |
| Legacy endpoint security (intents) | `/beta/deviceManagement/intents` |
| Compliance policies | `/v1.0/deviceManagement/deviceCompliancePolicies` (`scheduledActionsForRule` required on create) |
| Compliance scripts | `/beta/deviceManagement/deviceComplianceScripts` |
| Platform scripts | `/beta/deviceManagement/deviceManagementScripts` |
| Remediations | `/beta/deviceManagement/deviceHealthScripts` |
| Apps | `/beta/deviceAppManagement/mobileApps` (filter by `@odata.type`, for example `#microsoft.graph.win32LobApp`) |
| App protection | `/beta/deviceAppManagement/managedAppPolicies`, `/iosManagedAppProtections`, `/androidManagedAppProtections` |
| App configuration | `/beta/deviceAppManagement/mobileAppConfigurations`, `/targetedManagedAppConfigurations` |
| Managed devices | `/v1.0/deviceManagement/managedDevices` |
| Autopilot devices | `/beta/deviceManagement/windowsAutopilotDeviceIdentities` |
| Autopilot profiles | `/beta/deviceManagement/windowsAutopilotDeploymentProfiles` |
| ESP and enrollment restrictions | `/beta/deviceManagement/deviceEnrollmentConfigurations` |
| Assignment filters | `/beta/deviceManagement/assignmentFilters` |
| Update rings | `/beta/deviceManagement/deviceConfigurations` filtered to `windowsUpdateForBusinessConfiguration` |
| Feature update profiles | `/beta/deviceManagement/windowsFeatureUpdateProfiles` |
| Scope tags | `/beta/deviceManagement/roleScopeTags` |

Always verify an endpoint against the current Graph docs before handing it over as final.

## Patterns

- **Paging:** follow `@odata.nextLink` until empty. `scripts/IntuneGraph.Common.ps1` has `Invoke-IntuneGraphPaged`.
- **Throttling:** on 429 honour `Retry-After`. The helper retries with back-off.
- **Assignments:** settings catalog uses `POST /{id}/assign` with the full assignments list (it replaces existing). Read existing assignments first and merge.
- **Assignment target types:** `#microsoft.graph.groupAssignmentTarget`, `exclusionGroupAssignmentTarget`, `allDevicesAssignmentTarget`, `allLicensedUsersAssignmentTarget`, optionally with `deviceAndAppManagementAssignmentFilterId` and `deviceAndAppManagementAssignmentFilterType` (`include` or `exclude`).
- **Copy a policy between tenants:** export JSON, strip read-only properties (`id`, `createdDateTime`, `lastModifiedDateTime`, `version`, `settingCount`, `@odata.context`, `assignments`), POST to the target, then recreate assignments with the target tenant's group IDs.
- **Bulk device actions:** POST to `/managedDevices/{id}/syncDevice`, `/rebootNow`, `/windowsDefenderScan`, `/rotateBitLockerKeys` etc. Always run a report-only pass first and require explicit confirmation of the count.

## Scripts in this skill

| Script | Purpose |
|---|---|
| `IntuneGraph.Common.ps1` | Shared functions: connect, paged GET, retry, group name lookup |
| `Export-IntuneConfig.ps1` | Back up config, compliance, scripts, remediations, apps metadata, filters to JSON |
| `Get-IntuneAssignmentReport.ps1` | Every policy/app and who it is assigned to (with filters), as CSV |
| `Get-IntuneComplianceReport.ps1` | Device compliance state, last sync, OS, user, as CSV |
| `Get-IntuneStaleDevices.ps1` | Devices not synced in N days, report only by default |
| `New-IntunePolicyFromJson.ps1` | Create a settings catalog or compliance policy from a JSON file, optionally assign to a group (supports -WhatIf) |
