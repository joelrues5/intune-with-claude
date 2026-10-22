# Enrollment and Autopilot

## Windows enrollment options

| Scenario | Method |
|---|---|
| New corporate devices, user-driven, cloud native | Windows Autopilot (user-driven, Entra joined) or Autopilot device preparation |
| Shared, kiosk, meeting room | Autopilot self-deploying mode (needs TPM 2.0 attestation) or pre-provisioning |
| Existing domain joined fleet | Hybrid Entra join via Entra Connect, then GPO-based MDM auto-enrollment or co-management with ConfigMgr |
| BYOD Windows | Usually block personal Windows enrollment and use MAM/web access instead |
| Bulk without user (labs, schools) | Provisioning package (Windows Configuration Designer) or self-deploying |

Prerequisites that are commonly missed:
- MDM user scope (Entra ID > Mobility (MDM and WIP) > Microsoft Intune) set to All or a group that includes the users.
- Users licensed for Intune.
- Device platform restrictions allowing Windows (MDM), and personally owned blocked if intended.
- Entra device settings: users may join devices to Entra ID, device limit per user.
- Automatic enrollment CNAMEs (enterpriseenrollment and enterpriseregistration) for custom domains help with some flows.

## Classic Autopilot (hardware hash)

1. Register devices: OEM/reseller upload (best), CSV import, or capture the hash: `Install-Script Get-WindowsAutopilotInfo; Get-WindowsAutopilotInfo -Online` (the script and its Graph dependencies change over time; verify the current method). Group tag set at import drives dynamic groups.
2. Dynamic device group for Autopilot devices, for example: `(device.devicePhysicalIds -any (_ -startsWith "[OrderID]:SALES"))` for a group tag of SALES, or `(device.devicePhysicalIDs -any (_ -startsWith "[ZTDId]"))` for all Autopilot devices.
3. Deployment profile: user-driven, Entra joined, hide EULA/privacy/change account options, user account type Standard, apply device name template (for example `CORP-%RAND:6%`; names max 15 characters, so `%SERIAL%` with a long serial gets truncated).
4. Enrollment Status Page (ESP): block device use until required apps install, list only critical blocking apps (security agent, VPN, Company Portal, Microsoft 365 Apps), timeout 60 to 90 minutes, allow reset on failure for pilots.
5. Assign profile and ESP to the Autopilot device group.

Hybrid Entra join with Autopilot needs the Intune Connector for Active Directory, a Domain Join profile, and line of sight to a DC during OOBE (or VPN). Microsoft recommends Entra join for new deployments; push back on hybrid unless there is a hard dependency.

## Autopilot device preparation

- Newer flow that does not require hash pre-registration; device group membership is set during provisioning via a device group with the "Intune Provisioning Client" service principal as owner.
- Fewer options than classic (check current feature gaps such as self-deploying and pre-provisioning support before choosing it).
- Good for: quick onboarding, reporting per deployment, Windows 365.

## Apple

- **ADE (Automated Device Enrollment):** link Apple Business Manager to Intune with an ADE token (renew yearly), create an enrollment profile (user affinity, Setup Assistant with modern authentication, supervised, locked enrollment), assign devices in ABM to the Intune MDM server.
- **BYOD iOS:** account driven user enrollment or device enrollment via Company Portal; prefer MAM-only for most BYOD.
- **macOS:** ADE with Platform SSO is the modern path.
- Renew the Apple MDM push certificate yearly using the **same Apple ID**. Letting it expire or renewing with a different Apple ID forces re-enrollment of every Apple device.

## Android Enterprise

- Link managed Google Play account first.
- Corporate: fully managed (QR or zero-touch), dedicated (kiosk, shared device mode), corporate-owned work profile.
- BYOD: personally-owned work profile.
- Enrollment tokens for corporate modes expire; track them.

## Enrollment restrictions

- Device platform restrictions: per platform allow/block, min/max OS, block personally owned.
- Device limit restrictions: Intune default 5 per user (Entra has its own separate limit).
- Device enrollment managers (DEM) bypass limits but break user affinity features; avoid unless needed.
- Corporate device identifiers (IMEI or serial) mark devices as corporate before enrollment.

## Device clean-up rules

- Devices > Device clean-up rules: remove devices that have not checked in for N days (for example 90 to 180). This removes the Intune record only, not the Entra device or Autopilot registration.
- Use `scripts/Get-IntuneStaleDevices.ps1` to report first.

## Re-provisioning options

| Action | Keeps | Use when |
|---|---|---|
| Autopilot reset | Entra join, Intune enrollment, Wi-Fi | Re-purpose for a new user quickly |
| Fresh start | Enrollment, removes OEM apps | Clean up OEM bloat |
| Wipe | Nothing (optionally keep enrollment state) | Full rebuild |
| Retire | Personal data | BYOD leaver |

All are destructive; confirm targets before running, especially in bulk.
