# Naming, groups, filters and governance

## Naming convention

Pattern: `<Platform>-<Type>-<Scope>-<Purpose>-<Version>`

| Part | Values |
|---|---|
| Platform | WIN, MAC, IOS, AND, ALL |
| Type | SC (settings catalog), EP (endpoint security), BL (baseline), CP (compliance), TPL (template), ADMX, OMA, APP, APP-P (app protection), APP-C (app config), REM (remediation), PS (platform script), UR (update ring), FU (feature update), AP (Autopilot profile), ESP |
| Scope | PROD, PILOT, or a department/site code |
| Purpose | Short readable description |
| Version | v1, v2 ... (bump when making a breaking change, keep old one until migrated) |

Examples: `WIN-EP-PROD-BitLocker-v1`, `WIN-CP-PROD-Baseline-v2`, `IOS-APP-P-PROD-Level2-v1`, `WIN-REM-PROD-DisablePSv2-v1`.

Always fill in the Description field: owner, change ticket, date, and what it does.

## Groups

| Group | Type | Membership |
|---|---|---|
| `INT-DEV-WIN-All` | Dynamic device | `(device.deviceOSType -eq "Windows") and (device.managementType -eq "MDM")` |
| `INT-DEV-WIN-Autopilot` | Dynamic device | `(device.devicePhysicalIDs -any (_ -startsWith "[ZTDId]"))` |
| `INT-DEV-WIN-Pilot` | Assigned device | IT and champion devices |
| `INT-USR-Pilot` | Assigned user | IT and champions |
| `INT-DEV-IOS-Corporate` | Dynamic device | `(device.deviceOSType -eq "iPhone") -or (device.deviceOSType -eq "iPad")` with ownership filter via assignment filter |
| `INT-DEV-WIN-Ring-Early` / `-Broad` | Assigned or dynamic | Update and policy rings |

Dynamic group processing can take minutes to hours; do not rely on it for time-critical Autopilot assignment unless planned.

## Assignment filters

Use filters (Tenant administration > Filters) to narrow an assignment instead of creating more groups. Examples:

- Corporate only: `(device.deviceOwnership -eq "Corporate")`
- Windows 11 only: `(device.osVersion -startsWith "10.0.22") or (device.osVersion -startsWith "10.0.26")`
- Exclude virtual machines: `(device.model -notContains "Virtual")`
- Specific enrollment profile: `(device.enrollmentProfileName -eq "Autopilot-Standard")`

Preview the filter against devices before assigning.

## Assignment rules of thumb

- Device settings target device groups. User-specific settings and Available apps target user groups.
- Do not mix user and device groups in include/exclude for the same object; exclusions across types do not evaluate the way people expect.
- "All devices" and "All users" virtual groups are fast and efficient; combine them with filters instead of a giant dynamic group, once a policy is proven.
- Pilot first, always.

## Governance

- **RBAC:** custom roles for helpdesk (read, sync, restart, BitLocker key view), app packagers, and policy admins. Scope tags per site or customer to limit visibility.
- **Multi admin approval:** require a second admin for scripts, apps and wipe actions in production.
- **Audit logs:** Tenant administration > Audit logs; export regularly or stream to Log Analytics.
- **Backups:** export config weekly (`scripts/Export-IntuneConfig.ps1` or IntuneCD) to a private Git repo so changes are diffable.
- **Documentation:** a change record per policy (`templates/change-record.md`), and a living tenant baseline document.
