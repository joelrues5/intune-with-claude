# Windows updates

## Building blocks

| Policy | Controls |
|---|---|
| Update rings for Windows 10 and later | Quality and feature deferrals, deadlines, grace period, restart behaviour, pause |
| Feature updates for Windows 10 and later | Pins devices to a target Windows version (for example a Windows 11 release) until you move it |
| Quality updates (expedite) | Push a specific security update fast regardless of deferrals |
| Driver and firmware updates | Approve drivers manually or automatically via Windows Update for Business deployment service |
| Windows Autopatch | Microsoft-managed rings and release orchestration (licensing applies) |
| Hotpatch | Security updates without restart on eligible devices and licences |

## Suggested ring design

| Ring | Group | Quality deferral | Feature deferral | Deadline (quality) | Grace |
|---|---|---|---|---|---|
| Pilot / IT | IT staff devices | 0 days | 0 | 2 days | 1 day |
| Early | 10 percent of users across departments | 3 days | 0 (controlled by Feature updates policy) | 3 days | 2 days |
| Broad | Everyone else | 7 days | 0 | 5 days | 2 days |
| Critical / exempt | Devices that cannot restart freely | 10 days | 0 | 7 days | 3 days |

- Use the **Feature updates** policy to control the Windows version, and leave feature deferral at 0 in rings so they do not fight.
- Set "Use deadline settings" so devices actually restart. Without deadlines, compliance with patching will drift.
- Avoid conflicting GPO (WSUS settings, `DisableDualScan`, or "Configure Automatic Updates") on hybrid joined devices; set the Windows Update workload to Intune if co-managed.

## Reporting

- Reports > Windows updates (Windows Feature Update report, Windows Expedited Update report).
- Windows Update for Business reports (Azure Monitor / Log Analytics workbook) for detailed status.
- Pair with an Essential Eight patch timeframe if the client is assessed against it.
