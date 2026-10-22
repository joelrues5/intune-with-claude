# App deployment

## Picking the app type (Windows)

| Source | Intune app type | When |
|---|---|---|
| Anything with an installer (EXE, MSI with transforms, scripts, multiple files) | Windows app (Win32), packaged with IntuneWinAppUtil | Default for line of business on Windows. Detection, requirements, dependencies, supersedence, return codes, delivery optimisation |
| App in the Microsoft Store or winget msstore source | Microsoft Store app (new) | Auto updates from the Store. Can run in System context |
| Common third party app (Chrome, 7-Zip, Notepad++, Zoom, Adobe Reader) with an Intune Suite / Enterprise App Management licence | Enterprise App Catalog app | Microsoft-maintained packages and detection. Check licensing first |
| Single MSI with no extra files | Line-of-business (MSI) | Avoid in Autopilot ESP alongside Win32 apps (mixing LOB MSI and Win32 in ESP is a known cause of failures). Prefer Win32 |
| Microsoft 365 Apps | Microsoft 365 Apps (Windows 10 and later) built-in type, or Win32 with ODT and an XML | Built-in is simplest; ODT Win32 gives full control |
| Microsoft Edge | Built-in Edge app type | Usually already present on Windows 11 |
| Website shortcut | Web link | |

## Win32 packaging workflow

1. Get the silent install and uninstall commands. Test them as SYSTEM first: `psexec -s -i cmd.exe` (Sysinternals) then run the command.
2. Put the installer and any files in a source folder. Use `templates/Install-Win32App.ps1` as a wrapper when you need logging, pre-checks, closing processes, or multiple steps.
3. Package: `IntuneWinAppUtil.exe -c <SourceFolder> -s <SetupFile> -o <OutputFolder> -q`
4. Upload in Apps > Windows > Add > Windows app (Win32).
5. Program:
   - Install command, for example `powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Install-Win32App.ps1 -Action Install`
   - Install behaviour: System for machine-wide installs, User for per-user installs (user must be signed in).
   - Device restart behaviour: "Determine behavior based on return codes" in most cases.
   - Return codes: 0 success, 1707 success, 3010 soft reboot, 1641 hard reboot, 1618 retry (another install in progress).
6. Requirements: OS architecture (x64, arm64), minimum OS, disk space, and requirement scripts for things like "only if the old version is present".
7. Detection (pick one, prefer the most specific):
   - MSI product code (with version check if needed).
   - File or folder existence/version (for example `%ProgramFiles%\Vendor\App\app.exe` version >= X).
   - Registry value.
   - Custom detection script: must exit 0 **and** write something to STDOUT to be detected. Exit 0 with no output, or any non-zero exit, means not detected. Template: `templates/Win32-Detection.ps1`.
8. Dependencies (installed first, auto-install option) and supersedence (replace or update older app; uninstall previous version option).
9. Assign: Required (device or user group), Available for enrolled devices (Company Portal), Uninstall. Set delivery optimisation priority and restart grace period as needed.

### 32-bit vs 64-bit gotcha

The Intune Management Extension has historically launched install commands in a 32-bit context on 64-bit Windows, which redirects `Program Files` and `HKLM\SOFTWARE` to their 32-bit locations. If an installer or script must touch 64-bit locations, launch PowerShell with `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe` in the install command, or handle it in the wrapper. For detection scripts there is a "Run script as 32-bit process on 64-bit clients" toggle: leave it **No** so the script runs 64-bit. Verify current behaviour if it matters for the specific app.

### Updating an app

- New version, same detection logic: create a new Win32 app with updated detection (version >= new) and set supersedence on the old one, then move assignments. Avoid overwriting the content of an existing app in place because devices that already detected it will not reinstall.
- For auto-updating apps (Chrome, Zoom, Teams) consider letting the vendor updater handle it and detect "version >= baseline" rather than an exact version.

## Microsoft Store app (new)

- Apps > Windows > Add > Microsoft Store app (new) > search. Install behaviour System where supported.
- Uses the winget msstore source; Store must not be blocked by policy for the IME to install (blocking the Store app UI is fine, blocking the Store service is not).

## Microsoft 365 Apps

- Channel: Monthly Enterprise or Current for most SMB/MSP clients; Semi-Annual Enterprise for change-controlled orgs.
- Remove MSI Office first (built-in option). Shared computer activation for RDS/AVD/shared devices.

## Mobile apps

- **iOS / iPadOS:** Apple Business Manager (or School Manager) with VPP tokens. Assign device licensing for supervised devices so no Apple ID is needed. Line-of-business IPA needs re-signing before expiry.
- **Android:** Managed Google Play, approve apps in the managed Play iframe in Intune, then assign. Private apps and web apps can be published from the same iframe.
- **macOS:** PKG (unsigned and signed supported in the macOS app (PKG) type), DMG, Microsoft 365 Apps for macOS, Edge, Defender built-ins.

## App protection (MAM) for BYOD

- Use App protection policies (Apps > App protection policies) for iOS and Android, optionally Windows MAM for Edge.
- Microsoft's data protection framework levels: Level 1 basic, Level 2 enhanced, Level 3 high. Level 2 suits most organisations.
- Typical Level 2: block backup to iTunes/iCloud/Google, restrict cut/copy/paste to policy managed apps with paste in, require PIN or biometrics, block save as except OneDrive and SharePoint, wipe after 90 days offline, minimum app and OS versions.
- Pair with CA "Require app protection policy" for Exchange Online and SharePoint Online on iOS and Android.
- App configuration policies set app-level options (for example Outlook account setup, Edge managed bookmarks).

## Assignment intent cheat sheet

| Intent | Target | Effect |
|---|---|---|
| Required | Device group | Installs regardless of who signs in, works pre-logon (ESP device phase) |
| Required | User group | Installs on every device the user signs into |
| Available | User group | Shows in Company Portal; device groups are not supported for Available on Windows |
| Uninstall | Device or user group | Removes the app when detected |
| Exclude | Group | Exclusions win over inclusions; do not mix user and device group types between include and exclude |

## Troubleshooting apps

See `troubleshooting.md` for IME logs, AppWorkload.log, and common error codes.
