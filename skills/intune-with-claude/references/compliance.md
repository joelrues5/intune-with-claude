# Compliance

Compliance policies decide whether a device is compliant. Conditional Access uses that state to grant or block access. Compliance on its own does not change device settings; configuration policies do that.

## Tenant-wide compliance settings (check these first)

Devices > Compliance > Compliance settings:

- **Mark devices with no compliance policy assigned as:** set to **Not compliant**. The default (Compliant) lets unmanaged-by-policy devices through CA.
- **Compliance status validity period (days):** default 30. Devices that do not check in within this window go noncompliant.
- **Enhanced jailbreak detection** (iOS): enable if iOS is in scope.

## Recommended Windows baseline compliance

| Setting | Value | Notes |
|---|---|---|
| Require BitLocker | Require | Device Health Attestation based; reported after reboot. Expect a short lag on new devices |
| Require Secure Boot | Require | |
| Require code integrity | Require | |
| Minimum OS version | Current supported Windows 11 build minus one | Windows 10 left mainstream support on 14 Oct 2025; treat Windows 10 as legacy unless on ESU |
| Firewall | Require | |
| Antivirus / Antispyware | Require | |
| Microsoft Defender Antimalware, real time protection | Require | |
| Defender security intelligence up to date | Require | Can flap on devices offline for a while; consider grace period |
| Require device to be at or under machine risk score | Medium or Low | Needs Defender for Endpoint connector enabled in Intune and MDE onboarding |
| Require TPM | Require | |
| Password | Usually left to Windows Hello / config profiles | Setting password rules in compliance can force password prompts on Entra joined devices |

## Mobile baselines

- **iOS:** minimum OS (current minus one major), jailbroken devices blocked, passcode required (if not handled by config), MDE risk level if MTD in use.
- **Android Enterprise:** Play Integrity verdict (basic integrity and device integrity), block rooted, minimum security patch level (within roughly 90 days), minimum OS, encryption required.
- **macOS:** minimum OS, FileVault, SIP, firewall, Gatekeeper.

## Actions for noncompliance

- Mark noncompliant: default immediate. Add a **grace period** (for example 1 to 3 days) for user-fixable issues so users are not cut off mid-day.
- Send email to end user (create a notification template under Compliance > Notifications first).
- Remote lock (mobile), retire (add to retire list), push notification.
- Retire actions are destructive. Use long schedules (for example 90 days) and only after communication.

## Custom compliance (Windows)

For anything the built-in settings do not cover (an agent installed and running, a registry value, a specific app version):

1. Write a **discovery script** (PowerShell) that outputs a single compressed JSON object to STDOUT. Upload under Devices > Compliance > Scripts.
2. Write a **JSON rules file** that defines each setting name, operator, data type, operand and remediation message.
3. Reference both in a Windows compliance policy under Custom Compliance.

Constraints: script runs as SYSTEM in 64-bit if configured, output must be one line of JSON, keep it fast (it runs every check-in). Templates: `templates/custom-compliance-discovery.ps1` and `templates/custom-compliance-rules.json`.

## Rollout pattern

1. Create compliance policy, assign to pilot device group, no CA yet.
2. Run the Device compliance report and per-setting status for 1 to 2 weeks. Fix the noncompliant devices or the policy.
3. Turn on CA "Require device to be marked as compliant" in **report-only**, review sign-in logs.
4. Enforce CA for pilot users, then expand.

## Reports

- Devices > Monitor > Device compliance, Noncompliant devices and settings, Setting compliance.
- Graph: `GET /v1.0/deviceManagement/managedDevices?$select=deviceName,complianceState,lastSyncDateTime,userPrincipalName,operatingSystem,osVersion`
- Per-policy: `GET /v1.0/deviceManagement/deviceCompliancePolicies/{id}/deviceStatuses`
- Script: `scripts/Get-IntuneComplianceReport.ps1`.

## Graph creation note

When creating a compliance policy via Graph you must include `scheduledActionsForRule` with at least a block action, or the POST fails. See `templates/compliance-windows-baseline.json`.

## Common gotchas

- "Not evaluated" or "In grace period" appear while the device has not checked in since assignment.
- BitLocker, Secure Boot and code integrity come from Device Health Attestation; a device needs a reboot after enabling before they report correctly.
- A device that belongs to multiple compliance policies must pass all of them.
- Users with multiple devices: CA evaluates the device they sign in from, not the user.
