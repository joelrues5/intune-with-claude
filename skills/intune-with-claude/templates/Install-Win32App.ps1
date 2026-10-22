<#
.SYNOPSIS
    Generic Win32 install/uninstall wrapper for Intune.

.DESCRIPTION
    Package this file with the installer using IntuneWinAppUtil.exe. Use as:

      Install:   %SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Install-Win32App.ps1 -Action Install
      Uninstall: %SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Install-Win32App.ps1 -Action Uninstall

    Sysnative forces 64-bit PowerShell when the Intune Management Extension starts the
    command from a 32-bit context. If Sysnative does not exist (already 64-bit), use
    powershell.exe directly.

    The script:
      - logs to C:\ProgramData\IntuneScripts\Logs\<AppName>.log
      - optionally closes running processes first
      - runs the installer and passes its exit code back to Intune
        (0 success, 3010 soft reboot, 1641 hard reboot, 1618 retry)

.PARAMETER Action
    Install or Uninstall.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action = 'Install'
)

# ===== CONFIG =====
$AppName          = 'ExampleApp'
$InstallFile      = 'ExampleAppSetup.msi'              # file in the package folder, .msi or .exe
$InstallArgs      = '/qn /norestart ALLUSERS=1'        # for .exe use the vendor's silent switches
$UninstallFile    = 'msiexec.exe'
$UninstallArgs    = '/x {00000000-0000-0000-0000-000000000000} /qn /norestart'
$ProcessesToClose = @('exampleapp')                    # process names without .exe, or @()
# ==================

$LogDir  = Join-Path $env:ProgramData 'IntuneScripts\Logs'
$LogFile = Join-Path $LogDir "$AppName.log"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $line = "{0}  [{1}]  {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Action, $Message
    Add-Content -Path $LogFile -Value $line
    Write-Output $line
}

function Stop-AppProcesses {
    foreach ($p in $ProcessesToClose) {
        $running = Get-Process -Name $p -ErrorAction SilentlyContinue
        if ($running) {
            Write-Log "Stopping process $p"
            $running | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    Write-Log "Starting. Running as $([Environment]::UserName), 64-bit process: $([Environment]::Is64BitProcess)"
    Stop-AppProcesses

    if ($Action -eq 'Install') {
        $installer = Join-Path $PSScriptRoot $InstallFile
        if (-not (Test-Path $installer)) { throw "Installer not found: $installer" }

        if ($installer -like '*.msi') {
            $msiLog = Join-Path $LogDir "$AppName-msi.log"
            $file = 'msiexec.exe'
            $arguments = "/i `"$installer`" $InstallArgs /l*v `"$msiLog`""
        }
        else {
            $file = $installer
            $arguments = $InstallArgs
        }
    }
    else {
        $file = $UninstallFile
        $arguments = $UninstallArgs
    }

    Write-Log "Running: $file $arguments"
    $proc = Start-Process -FilePath $file -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    $code = $proc.ExitCode
    Write-Log "Exit code: $code"

    switch ($code) {
        0       { Write-Log 'Success' }
        1707    { Write-Log 'Success (1707)' }
        3010    { Write-Log 'Success, soft reboot required' }
        1641    { Write-Log 'Success, hard reboot initiated' }
        1618    { Write-Log 'Another installation in progress, Intune will retry' }
        default { Write-Log 'Installer returned a failure code' }
    }
    exit $code
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1603
}
