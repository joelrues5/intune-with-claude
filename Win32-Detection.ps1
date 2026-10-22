<#
.SYNOPSIS
    Win32 app custom detection script template.

.DESCRIPTION
    Win32 detection rules (different from Remediations):
      Detected     = exit 0 AND something written to STDOUT
      Not detected = exit 0 with no STDOUT, or any non-zero exit code

    Set "Run script as 32-bit process on 64-bit clients" to No.
    Do not write anything to STDOUT unless the app is detected.

    This example checks the uninstall registry for a display name and minimum
    version, which survives most vendor installers (EXE or MSI).
#>

# ===== CONFIG =====
$DisplayNameLike = 'Example App*'
$MinimumVersion  = [version]'1.2.3'
# ==================

$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$found = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like $DisplayNameLike -and $_.DisplayVersion }

foreach ($app in $found) {
    $installed = $null
    if ([version]::TryParse(($app.DisplayVersion -replace '[^0-9\.]', ''), [ref]$installed)) {
        if ($installed -ge $MinimumVersion) {
            Write-Output "Detected $($app.DisplayName) $installed"
            exit 0
        }
    }
}

# Not detected: no output, exit 0
exit 0
