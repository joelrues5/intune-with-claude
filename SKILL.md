---
name: intune-management
description: Use when designing, building, deploying, automating, auditing or troubleshooting Microsoft Intune - configuration and settings catalog policies, compliance, app deployment (Win32, MSI, Store, LOB, iOS/Android), Autopilot and enrollment, Conditional Access integration, scripts and Remediations, update rings, and Microsoft Graph automation for Intune.
---

# Intune with Claude

Helps an endpoint engineer or MSP consultant manage Microsoft Intune end to end: decide the right policy type, build it (portal steps, JSON for Graph, or PowerShell), assign it safely, prove it worked, and fix it when it does not.

## 0. Freshness check (do this first for anything version-sensitive)

Intune ships monthly service releases and the portal moves often. Before quoting a blade path, a setting name, a licensing boundary or a Graph endpoint as current:

- Run a quick web search ("Intune what's new <current month year>", or the specific feature name) and prefer learn.microsoft.com and Message Center (MC) posts.
- Treat these as frequently changing: portal navigation paths, Intune Suite / add-on licensing (Remote Help, EPM, Enterprise App Management, Advanced Analytics, Cloud PKI), Windows feature update targets, Apple and Android OS minimums, and anything still in preview.
- Most Intune Graph endpoints live under `/beta`. Say so when you give one, because beta can change without notice.
- If you could not verify something, say so plainly instead of presenting it as fact.

## 1. Capture context (ask only for what is missing)

| Item | Why it matters |
|---|---|
| Platforms and join type (Entra joined, hybrid joined, registered, BYOD, kiosk/shared, iOS ADE, Android Enterprise mode, macOS) | Decides which profile types and settings exist |
| Licensing (Business Premium, M365 E3/E5, Intune Plan 1, Intune Suite add-ons, Defender for Endpoint plan, Entra ID P1/P2) | Decides what is even possible (CA needs P1, Remediations need E3/E5 or equivalent, EPM is an add-on) |
| Co-management with ConfigMgr, GPO still in play, other RMM | Avoids two engines fighting over the same setting |
| Pilot group available? Change window? | Every change goes pilot first |
| Output wanted: portal walkthrough, JSON body, PowerShell, documentation, or a client deliverable | Shapes the answer |
| Compliance framework in scope (Essential Eight, CIS, ISO 27001, ACSC hardening, NIST) | Drives the setting values |

If an Essential Eight question comes up and the `essential-eight-compliance` skill is available, use that for maturity requirements and come back here for the Intune build.

## 2. Route the request

| Request | Read |
|---|---|
| Device restrictions, settings catalog, templates, security baselines, ADMX, OMA-URI, BitLocker, Defender, firewall, ASR, LAPS, Windows Hello | `references/configuration-policies.md` |
| Compliance policies, grace periods, custom compliance, noncompliance actions | `references/compliance.md` |
| Deploying or updating apps, Win32 packaging, detection rules, supersedence, Store, VPP, Managed Google Play, App protection (MAM) | `references/app-deployment.md` |
| Autopilot, enrollment restrictions, ESP, ADE, Android Enterprise, device cleanup | `references/enrollment-autopilot.md` |
| Conditional Access with device compliance, require compliant device, filters for devices | `references/conditional-access.md` |
| Platform scripts, Remediations (detect/remediate), custom inventory | `references/scripts-remediations.md` |
| Windows Update rings, feature updates, quality updates, driver updates, Autopatch | `references/updates.md` |
| Automating anything with Graph or PowerShell, export/backup, bulk changes, reporting | `references/graph-automation.md` |
| "It isn't applying", conflicts, errors, logs, sync problems | `references/troubleshooting.md` |
| Naming, groups, filters, assignment strategy, tenant governance | `references/naming-and-assignment.md` |

Load only the reference files you need. Several may apply to one task (for example a Win32 app plus a Remediation plus a compliance rule).

## 3. How to build anything in Intune

Follow this order for every new policy, app or script:

1. **Pick the right object type.** Prefer, in order: security baseline or endpoint security profile (if it covers the need) > settings catalog > templates > ADMX import > custom OMA-URI. Do not use a legacy template when the setting exists in the settings catalog. See the decision table in `references/configuration-policies.md`.
2. **Check for overlap.** Ask (or check via Graph) whether another policy, baseline, GPO or co-management workload already sets the same thing. Conflicts are the number one cause of "it isn't applying".
3. **Name it** using the convention in `references/naming-and-assignment.md`.
4. **Define settings with intent.** For each setting give the value, why, and the user impact. Flag anything that can lock users out, break apps, or force reboots.
5. **Assign safely.** Pilot group first, then rings. Prefer device groups for device settings, user groups for user settings and apps that follow the user. Use assignment filters instead of making extra groups where possible. Never assign untested policy to All Devices or All Users.
6. **Verify.** Say exactly where to confirm success (per-setting status report, device configuration report, MDM diagnostic report, registry/CSP path, event log) and what "good" looks like.
7. **Rollback plan.** State how to back it out (unassign, exclude, or a reverse policy) and whether the setting tattoos (stays after removal).
8. **Document.** Offer a change record using `templates/change-record.md`.

## 4. Output formats

- **Portal walkthrough:** numbered steps with the blade path. Start paths from the Intune admin center (intune.microsoft.com). Note the path may drift and was correct at time of writing.
- **Graph JSON:** a complete, valid request body plus the method and endpoint. Mark `/beta`. Use placeholders like `<GROUP-OBJECT-ID>`, never invented GUIDs that look real.
- **PowerShell:** use the Microsoft Graph PowerShell SDK (`Microsoft.Graph.Authentication` and `Invoke-MgGraphRequest`) unless the user asks otherwise. The old `Microsoft.Graph.Intune` (Intune PowerShell SDK) and AzureAD modules are retired; do not use them. Include `#Requires`, the scopes needed, `-WhatIf` style safety where it changes things, and comments. Reuse the helpers in `scripts/`.
- **Detection / remediation scripts:** start from `templates/`. Exit codes matter: detection exit 0 = compliant / found, exit 1 = not compliant / not found (Remediations); Win32 detection = exit 0 AND write to STDOUT.
- **Client-facing deliverable:** plain English, outcomes first, settings table in an appendix.

## 5. Safety rules

- Never recommend a change that could brick or lock out devices (BitLocker without recovery key escrow, Windows Hello enforcement without fallback, ASR in block mode with no audit phase, WDAC/App Control in enforce without audit, wipe or retire actions, deleting devices in bulk) without stating the risk and a staged rollout.
- Device actions (wipe, retire, delete, fresh start, Autopilot reset, BitLocker key rotation) are destructive. Always confirm target, scope and count before giving a script that runs them, and default scripts to report-only.
- Graph scripts default to read-only scopes. Ask for write scopes only when the task needs them, and say which ones.
- Do not hard code secrets, tenant IDs or client secrets in scripts. Use interactive auth, certificate auth, or managed identity, and parameters.
- If the user pastes tenant exports, treat device names, UPNs and serials as sensitive. Do not echo more than needed.

## 6. Common quick answers

- **Sync now:** Company Portal > Settings > Sync, or Devices > device > Sync in admin center, or `Get-ScheduledTask -TaskName 'PushLaunch' | Start-ScheduledTask` on Windows. Check-in is roughly every 8 hours otherwise.
- **Force Win32 app re-evaluation:** restart the Intune Management Extension service (`Restart-Service IntuneManagementExtension`); logs at `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- **MDM diagnostic report:** Settings > Accounts > Access work or school > Info > Create report, or `mdmdiagnosticstool.exe -area DeviceEnrollment;DeviceProvisioning;Autopilot -cab C:\Temp\diag.cab`.
- **Policy CSP registry:** `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\<Area>` and `...\providers\<GUID>\default\device\<Area>`.
- **Effective group check:** Devices > device > Group membership, or the Assignments section of the policy, or `scripts/Get-IntuneAssignmentReport.ps1`.

## 7. Files in this skill

- `references/` - deep guidance per area (load on demand)
- `scripts/` - PowerShell helpers for Graph: connect, export/backup, assignment report, compliance report, create policy from JSON, stale device report
- `templates/` - JSON policy bodies, detection and remediation script templates, Win32 install wrapper, change record
