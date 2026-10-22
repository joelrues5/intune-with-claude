# Platform scripts and Remediations

## Which to use

| Need | Use |
|---|---|
| Run once (or once per change) at deployment, for example a one-off registry tweak | Platform script (Devices > Scripts and remediations > Platform scripts) |
| Detect drift and fix it on a schedule, with reporting | Remediation (detection + remediation script pair) |
| Report-only inventory or audit | Remediation with detection script only |
| Something that needs install logic, files or versioning | Win32 app with a script wrapper |
| Pass/fail state that should gate access | Custom compliance (see `compliance.md`) |

## Platform scripts

- Run via the Intune Management Extension (IME). Options: run as signed-in user or SYSTEM, enforce signature check, run in 64-bit host.
- Run once. They re-run only if the script content changes or it previously failed (IME retries up to 3 times).
- No exit code based detection or scheduling. If you need either, use a Remediation.
- Logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` (and AgentExecutor.log).

## Remediations

- Licensing: requires Windows Enterprise E3/E5, Education A3/A5, or Windows VDA per user (or included bundles such as Microsoft 365 E3/E5). Historically **not** included in Business Premium. Verify current licensing for the client.
- Detection script: exit **1** when the issue exists (triggers remediation), exit **0** when compliant.
- Remediation script: fixes it; exit 0 on success. The detection script runs again after remediation to confirm.
- Schedule: once, hourly, or daily. Run as SYSTEM or logged-on user, 64-bit toggle (use 64-bit).
- STDOUT is captured (last line, up to about 2048 characters) and visible in the report columns "Pre-remediation detection output" and "Post-remediation detection output". Write a short, useful status line.
- On-demand: "Run remediation" device action for a single device (Remediations licence required).
- Microsoft provides some built-in script packages; review before assigning.

Templates: `templates/Remediation-Detect.ps1`, `templates/Remediation-Remediate.ps1`.

## Script writing rules for Intune

- PowerShell 5.1 is what is guaranteed on Windows. Do not depend on PowerShell 7 unless you deploy it.
- Use full paths, never rely on mapped drives or user profile environment when running as SYSTEM.
- `HKCU` as SYSTEM is the SYSTEM hive. To set per-user registry as SYSTEM, enumerate `HKU\<SID>` for loaded profiles or run as the logged-on user.
- Avoid interactive prompts and `Read-Host`. Avoid long sleeps; scripts time out.
- Log to `C:\ProgramData\<Org>\Logs\<ScriptName>.log` so evidence survives.
- Make detection idempotent and fast.
- Keep files UTF-8 (no BOM issues for detection output) and avoid non-ASCII characters in output.

## Useful remediation ideas

- Disable PowerShell v2 optional feature.
- Ensure a service (security agent) is running and set to automatic.
- Clear stale Teams classic or remove unwanted OEM apps.
- Reset Windows Update components when stuck.
- Check and report BitLocker protector status, LAPS last rotation, local admin membership drift.
- Enforce a specific registry value that has no CSP (for example Office or third party setting).
