# Intune with Claude

A Claude skill (packaged as a Claude Code plugin) that helps you manage Microsoft Intune: build configuration and compliance policies, package and deploy apps, set up Autopilot, write Remediations, wire up Conditional Access, automate with Microsoft Graph, and troubleshoot when things do not apply.

It is written from an MSP and endpoint engineering point of view: pilot first, one owner per setting, verify and document every change.

## What it does

| Area | Examples |
|---|---|
| Configuration | Pick the right policy type (baseline, endpoint security, settings catalog, ADMX, OMA-URI), BitLocker, Defender, ASR, firewall, LAPS, Windows Hello |
| Compliance | Windows, iOS, Android and macOS baselines, grace periods, custom compliance scripts and rules |
| Apps | Win32 packaging and detection, supersedence, Microsoft Store, Microsoft 365 Apps, VPP, Managed Google Play, App protection (MAM) |
| Enrollment | Autopilot (classic and device preparation), ESP, ADE, Android Enterprise, enrollment restrictions, clean-up |
| Access | Conditional Access with compliant device, app protection, device filters |
| Scripts | Platform scripts vs Remediations, detection and remediation templates |
| Updates | Update rings, feature update targets, expedited quality updates, Autopatch |
| Automation | Graph endpoint map, scopes, PowerShell helpers for export, reporting and policy creation |
| Troubleshooting | Log locations, triage order, common errors |

## Repository layout

```
intune-with-claude/
  .claude-plugin/
    plugin.json
    marketplace.json
  skills/
    intune-with-claude/
      SKILL.md
      references/        deep guidance, loaded on demand
      scripts/           PowerShell helpers using Microsoft Graph
      templates/         JSON policy bodies, script templates, change record
  README.md
  CHANGELOG.md
  LICENSE
```

## Install

### Claude Code (plugin)

```
/plugin marketplace add joelrues5/intune-with-claude
/plugin install intune-with-claude@intune-with-claude
```

### Claude.ai or Claude desktop (skill upload)

1. Zip the `skills/intune-with-claude` folder so `SKILL.md` is at the top level of the zip.
2. In Claude, open Settings > Capabilities > Skills (location may vary) and upload the zip.

### Manual (Claude Code, no plugin)

Copy `skills/intune-with-claude` to `~/.claude/skills/intune-with-claude` (personal) or `.claude/skills/intune-with-claude` (project).

## Example prompts

- "Build a BitLocker policy for Entra joined Windows 11 devices with silent encryption, and give me the rollout plan."
- "Package Notepad++ as a Win32 app with a detection script and supersede the old version."
- "Write a Remediation that disables PowerShell v2 and reports the result."
- "Create a Windows compliance policy as Graph JSON and assign it to my pilot group."
- "Export every Intune policy and its assignments to CSV."
- "Autopilot is failing at ESP with a timeout. Where do I look?"
- "Design update rings for a 300-seat client with a pilot and broad ring."

## Scripts

All scripts use the Microsoft Graph PowerShell SDK (`Microsoft.Graph.Authentication`) and `Invoke-MgGraphRequest`.

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

| Script | Purpose | Changes things? |
|---|---|---|
| `Export-IntuneConfig.ps1` | Back up policies, scripts, apps metadata and assignments to JSON | No |
| `Get-IntuneAssignmentReport.ps1` | Every object and its assignments, with filter names, to CSV | No |
| `Get-IntuneComplianceReport.ps1` | Device compliance state and sync status to CSV | No |
| `Get-IntuneStaleDevices.ps1` | Devices not synced in N days | Report by default; Retire/Delete need typed confirmation and support `-WhatIf` |
| `New-IntunePolicyFromJson.ps1` | Create a settings catalog or compliance policy from JSON and optionally assign it | Yes; supports `-WhatIf` |

Most Intune endpoints are on Graph `beta` and can change without notice. Test in a non-production tenant first.

## Use with Essential Eight

If you also use the [essential-eight](https://github.com/joelrues5/essential-eight) skill, Claude will use that for maturity requirements and this skill for the Intune build and evidence.

## Disclaimer

Community project, not affiliated with or endorsed by Microsoft or Anthropic. Intune changes monthly; verify settings, licensing and endpoints against current Microsoft documentation before production use. Provided as is under the MIT licence.

## Contributing

Issues and pull requests welcome. Please do not include tenant IDs, device names, UPNs or exported tenant data in issues or commits.
