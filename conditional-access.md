# Conditional Access with Intune

Conditional Access (CA) lives in Entra ID (Protection > Conditional Access) and needs Entra ID P1 or above. Intune feeds it the device compliance signal.

## Before enforcing anything

- Create at least two **break-glass** cloud-only global admin accounts, exclude them from every CA policy, protect them with FIDO2 keys, and alert on their sign-ins.
- Start every new policy in **Report-only**. Review in Entra sign-in logs (Conditional Access and Report-only tabs) or the CA insights workbook.
- Confirm the tenant compliance setting "Mark devices with no compliance policy assigned as" is Not compliant.

## Core device-based policies

| Policy | Users | Apps | Conditions | Grant |
|---|---|---|---|---|
| Require compliant or hybrid joined device (Windows/macOS) | All users, exclude break-glass | All cloud apps (or Office 365 to start) | Device platforms Windows, macOS | Require device to be marked as compliant OR require Microsoft Entra hybrid joined device |
| Mobile: require app protection | All users | Office 365 | Platforms iOS, Android | Require app protection policy |
| Block unsupported platforms | All users | All cloud apps | Platforms: any, exclude Windows, macOS, iOS, Android | Block |
| Admins: compliant device + phishing-resistant MFA | Directory roles | All cloud apps | | Compliant device AND authentication strength phishing-resistant |

## Filters for devices

Use filters to include/exclude specific device types without extra groups, for example exclude shared kiosks:

`device.extensionAttribute1 -eq "Kiosk"` or `device.model -startsWith "Surface Hub"`.

Note: CA "filter for devices" uses Entra device properties; Intune "assignment filters" are a different feature with different properties.

## Gotchas

- Enrollment itself must not be blocked: Microsoft Intune Enrollment and Microsoft Intune cloud apps are commonly excluded from "require compliant device" policies, otherwise new devices cannot become compliant. Verify current guidance for the specific policy.
- Browser access on Windows needs the Edge profile signed in (or the Windows Accounts / Microsoft Single Sign On extension for Chrome) so the device identity is passed.
- Linux needs Microsoft Edge and the Intune app for Linux to report compliance.
- Hybrid joined devices that are not enrolled in Intune can satisfy "hybrid joined" but not "compliant". Choose deliberately.
- Token lifetimes mean a device going noncompliant does not cut access instantly, unless Continuous Access Evaluation applies.
