<#
.SYNOPSIS
    Custom compliance discovery script template (Windows).

.DESCRIPTION
    Upload under Devices > Compliance > Scripts. Pair with custom-compliance-rules.json.
    Must output ONE line of compressed JSON to STDOUT. Each key must match a
    SettingName in the rules file and the value type must match its DataType.

    Runs as SYSTEM. Set "Run this script using the logged on credentials" to No and
    "Run script in 64 bit PowerShell Host" to Yes.

    Keep it fast and quiet: no Write-Host, no prompts, nothing else on STDOUT.
#>

$ErrorActionPreference = 'SilentlyContinue'

# Replace with the service name of the agent you require.
$requiredService = 'Sense'

$service = Get-Service -Name $requiredService
$agentRunning = [bool]($service -and $service.Status -eq 'Running')

$psv2 = Get-WindowsOptionalFeature -Online -FeatureName 'MicrosoftWindowsPowerShellV2Root'
$psv2Disabled = [bool](-not $psv2 -or $psv2.State -ne 'Enabled')

$result = @{
    SecurityAgentRunning = $agentRunning
    PowerShellV2Disabled = $psv2Disabled
}

return $result | ConvertTo-Json -Compress
