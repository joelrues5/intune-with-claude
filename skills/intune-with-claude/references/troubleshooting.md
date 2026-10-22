# Troubleshooting

## Triage order

1. **Is the device actually managed and checking in?** Last check-in time in Intune, MDM authority, device ownership, user assigned.
2. **Is the policy assigned to this device or user?** Group membership (dynamic groups can take time), exclusions, assignment filters (use filter preview), user vs device targeting.
3. **Is it applicable?** Platform, OS edition (many settings need Enterprise or Education, not Pro), OS version, join type.
4. **Is there a conflict?** Per-setting status shows "Conflict". Look for overlapping profiles, baselines, GPO, ConfigMgr workloads.
5. **Did it apply but not take effect?** Check the CSP registry and the actual feature state; some settings need a reboot or sign-out.

## Where to look on Windows

| What | Where |
|---|---|
| MDM policy events | Event Viewer > Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider > Admin (and Operational) |
| Enrollment and Autopilot | Same provider, plus ModernDeployment-Diagnostics-Provider > Autopilot; `mdmdiagnosticstool.exe -area Autopilot -cab C:\Temp\ap.cab` |
| Applied policy values | `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\<Area>` |
| Win32 apps, scripts, remediations | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\` : `IntuneManagementExtension.log`, `AppWorkload.log` (app installs), `AgentExecutor.log` (scripts), `HealthScripts.log` (remediations) |
| Full report | Settings > Accounts > Access work or school > Export your management log files, or MDM diagnostic HTML report |
| BitLocker | Event Viewer > Microsoft > Windows > BitLocker-API > Management |
| Defender | `Get-MpComputerStatus`, `Get-MpPreference`, Event Viewer > Microsoft > Windows > Windows Defender > Operational |
| LAPS | Event Viewer > Microsoft > Windows > LAPS > Operational |

Tip: CMTrace (from ConfigMgr tools) or OneTrace makes the IME logs readable. Community "Get-IntuneManagementExtensionDiagnostics" style tools parse them into a timeline.

## Common symptoms

| Symptom | Likely cause | Check / fix |
|---|---|---|
| Policy "Pending" for days | Device not checking in, or user-targeted policy with no user signed in | Sync; confirm primary user; target devices for device settings |
| Setting shows "Error" 65000 | Generic failure, often edition not supported or CSP rejected the value | Check edition, value type, event log for the CSP error |
| "Not applicable" | Platform or edition mismatch, or applicability rule | Confirm Windows edition and OS version |
| "Conflict" | Two policies set different values | Find both in per-setting report, keep one owner |
| Win32 app "Install failed" with 0x87D1041C | Installed but detection rule did not find it | Fix detection (path, version, 32/64-bit, STDOUT for script) |
| Win32 app stuck "Install pending" | IME not running, waiting for user, or dependency failing | Restart IME service; check AppWorkload.log |
| 0x87D1FDE8 | Remediation (setting) failed | Event log for the CSP; often missing prerequisite |
| Autopilot ESP timeout | A blocking app failed or is slow, LOB MSI mixed with Win32 | Remove non-critical apps from blocking list; package as Win32 |
| Autopilot 0x80180014 | Commonly enrollment restriction (personal blocked, device previously deleted, or MDM blocked) | Check platform restrictions; re-import Autopilot hash; verify the code against current docs |
| Autopilot 0x80180018 | Commonly user not licensed or not in MDM user scope | Licence and MDM scope |
| Compliance "Not compliant" for BitLocker on a new device | Device Health Attestation not refreshed | Reboot after encryption, wait for check-in |
| Device compliant in Intune but blocked by CA | Device identity not passed (browser), or Entra device record mismatch | Edge profile signed in, check sign-in log device details |

Error codes are a pointer, not a diagnosis. Confirm against current Microsoft docs and the actual log line.

## iOS / Android / macOS

- iOS: Company Portal > device > Check status; Console logs on a Mac with Apple Configurator for deep issues; ADE token and push certificate validity.
- Android: Company Portal or Intune app > Help > Send logs (gives an incident ID for Microsoft support); Play Integrity failures on rooted or custom ROM devices.
- macOS: `log stream --predicate 'subsystem == "com.microsoft.intune"'`, Company Portal logs in `~/Library/Logs/Company Portal`, IME agent logs in `/Library/Logs/Microsoft/Intune`.

## Escalating to Microsoft

Collect: tenant ID, device ID (Intune and Entra), UPN, policy or app ID, time of failure (UTC), MDM diagnostic cab, IME logs, and steps to reproduce.
