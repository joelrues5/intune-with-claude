# Configuration policies

## Choosing the policy type

| Need | Use | Notes |
|---|---|---|
| Opinionated security config Microsoft maintains | Security baseline (Endpoint security > Security baselines) | Windows, Defender for Endpoint, Edge, Microsoft 365 Apps. Version them; do not edit a live baseline in production, create a new version and pilot it |
| Antivirus, firewall, disk encryption, ASR, EDR onboarding, account protection, LAPS, App Control | Endpoint security profiles | Scoped, reportable, and visible to security admins. Prefer these over generic config for security workloads |
| Almost any other Windows or macOS setting | Settings catalog | Default choice. Searchable, granular, per-setting reporting, supports Graph JSON export |
| A setting only in a legacy template (some Wi-Fi, VPN, certificate, kiosk, email, Domain Join for hybrid Autopilot) | Templates | Check settings catalog first each time; Microsoft keeps migrating |
| Third party app ADMX (Chrome, Zoom, Adobe, Office if not in catalog) | Imported administrative templates (ADMX) | Upload ADMX plus ADML; dependent ADMX files must be uploaded first |
| A CSP node not exposed anywhere else | Custom (OMA-URI) | Last resort. Document the CSP doc link and data type. Encrypted values are hidden in reports |
| iOS / iPadOS / macOS declarative device management | Settings catalog (DDM entries) | Prefer DDM software update settings for Apple updates where supported |

Rule of thumb: one setting, one owner. If a setting lives in a baseline, do not also set it in a settings catalog profile unless the values match.

## Windows building blocks (recommended defaults, adjust per client)

### Disk encryption (BitLocker)
- Endpoint security > Disk encryption > BitLocker profile.
- Silent encryption for Entra joined devices: require device encryption, allow standard users to enable encryption during Autopilot, disable third party encryption warning, OS drive XTS-AES 128 or 256.
- Recovery: store recovery info in Entra ID and **do not enable encryption until recovery info is stored**. This is the lockout guard.
- Key rotation on use: client-driven recovery password rotation enabled for Entra joined and hybrid joined devices.
- Verify: `manage-bde -status`, `Get-BitLockerVolume`, Entra device > BitLocker keys, Intune Encryption report.

### Microsoft Defender Antivirus
- Endpoint security > Antivirus > Microsoft Defender Antivirus.
- Real time protection on, cloud protection high, block at first sight on, PUA protection on (audit first if unsure), tamper protection via Defender for Endpoint or Intune.
- Exclusions: keep in a separate profile so they are reviewable. Never exclude broad paths like `C:\Users`.

### Attack surface reduction (ASR)
- Endpoint security > Attack surface reduction > Attack Surface Reduction Rules.
- Phase: Audit for 2 to 4 weeks, review in Defender portal (Reports > Attack surface reduction rules), then Block per rule, with per-rule exclusions only where justified.
- Safe to block early in most environments: block abuse of exploited vulnerable signed drivers, block credential stealing from LSASS, block persistence through WMI event subscription.
- Higher breakage risk (audit longer): block Office apps from creating child processes, block executable files unless they meet prevalence/age/trusted list, block process creations from PSExec and WMI commands (breaks ConfigMgr).

### Firewall
- Endpoint security > Firewall. Enable for domain, private, public. Inbound default block, outbound default allow. Rules in a separate Firewall Rules profile.

### Windows LAPS
- Endpoint security > Account protection > Local admin password solution (Windows LAPS).
- Backup directory Entra ID (cloud only or Entra joined) or AD (hybrid). Password complexity large letters + small + numbers + specials, length 14+, age 30 days, post-authentication actions reset password and log off.
- Legacy Microsoft LAPS is deprecated; do not deploy it to new builds.
- Requires the device to have the built-in admin or a named account to manage. Pair with a Local user group membership policy (Account protection) to control who is local admin.

### Windows Hello for Business
- Configure via settings catalog or Account protection, not only the tenant-wide enrollment setting.
- Roll out with a pilot. Cloud Kerberos trust is the simplest model for hybrid joined access to on-prem resources.

### Credential and OS hardening
- Credential Guard (often on by default on supported hardware for Windows 11 22H2+ Enterprise; set explicitly).
- LSA protection (RunAsPPL).
- SMB signing, disable LLMNR and NetBIOS where safe, disable Office macros from the internet (Microsoft 365 Apps baseline or ADMX).
- Disable PowerShell v2 via a Remediation or Win32 script (no CSP).

### Microsoft Edge and Microsoft 365 Apps
- Settings catalog has both (Microsoft Edge, Microsoft Office). Use the Edge and Microsoft 365 Apps security baselines as a starting point.

## macOS building blocks
- Platform SSO (Entra), FileVault with key escrow, firewall, Gatekeeper, system extensions and PPPC (privacy preferences) for Defender and other agents, DDM software update enforcement.
- Defender for Endpoint on macOS needs: system extension, full disk access, network filter, notifications profiles before the PKG lands. Microsoft publishes mobileconfig samples.

## iOS / iPadOS
- ADE supervised devices get the full restriction set. BYOD (user enrollment / account driven) gets far less; prefer App protection policies for BYOD.

## Android Enterprise
- Fully managed, dedicated (kiosk), corporate-owned work profile, personally-owned work profile. Policy types differ per mode; confirm mode first.

## Settings catalog via Graph

- Endpoint: `POST https://graph.microsoft.com/beta/deviceManagement/configurationPolicies`
- Body shape: `name`, `description`, `platforms` (for example `windows10`), `technologies` (`mdm`), `roleScopeTagIds`, `settings[]` each with `settingInstance` (`@odata.type`, `settingDefinitionId`, value).
- Easiest way to get a correct body: build the policy once in the portal, then GET it with `?$expand=settings` and reuse the JSON. `scripts/Export-IntuneConfig.ps1` does this.
- Assign with `POST .../configurationPolicies/{id}/assign` and an `assignments` array.
- Setting definitions searchable at `GET /beta/deviceManagement/configurationSettings?$filter=...`.

See `templates/settings-catalog-example.json`.

## Tattooing and removal

- Settings catalog and most CSP-based settings are removed when the policy is unassigned, but some CSPs tattoo (the value stays). Check the CSP doc for "removal" behaviour, and plan a reverse policy for anything critical.
- ADMX-backed settings set to "Disabled" vs "Not configured" behave differently: "Not configured" removes management, "Disabled" actively sets the off value.
