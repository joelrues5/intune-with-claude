#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helper functions for the Intune with Claude scripts.

.DESCRIPTION
    Dot-source this file from the other scripts:
        . "$PSScriptRoot\IntuneGraph.Common.ps1"

    Provides:
        Connect-IntuneGraph       Connect with delegated, certificate or managed identity auth
        Invoke-IntuneGraph        Single Graph call with retry on throttling (429) and 5xx
        Invoke-IntuneGraphPaged   GET that follows @odata.nextLink and returns all items
        Get-IntuneGroupName       Resolve an Entra group ID to a display name (cached)
        ConvertTo-SafeFileName    Make a policy name safe for use as a file name

.NOTES
    Requires the Microsoft.Graph.Authentication module:
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
#>

function Connect-IntuneGraph {
    [CmdletBinding(DefaultParameterSetName = 'Delegated')]
    param(
        [Parameter(Mandatory)]
        [string[]]$Scopes,

        [string]$TenantId,

        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [string]$ClientId,

        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [string]$CertificateThumbprint,

        [Parameter(ParameterSetName = 'ManagedIdentity', Mandatory)]
        [switch]$ManagedIdentity
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw "Microsoft.Graph.Authentication module not found. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $context = Get-MgContext
    if ($context -and $PSCmdlet.ParameterSetName -eq 'Delegated') {
        $missing = $Scopes | Where-Object { $context.Scopes -notcontains $_ }
        if (-not $missing -and (-not $TenantId -or $context.TenantId -eq $TenantId)) {
            Write-Verbose "Reusing existing Graph connection for tenant $($context.TenantId)"
            return
        }
    }

    switch ($PSCmdlet.ParameterSetName) {
        'Delegated' {
            $params = @{ Scopes = $Scopes; NoWelcome = $true }
            if ($TenantId) { $params.TenantId = $TenantId }
            Connect-MgGraph @params
        }
        'Certificate' {
            if (-not $TenantId) { throw "TenantId is required for certificate authentication." }
            Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -CertificateThumbprint $CertificateThumbprint -NoWelcome
        }
        'ManagedIdentity' {
            Connect-MgGraph -Identity -NoWelcome
        }
    }

    $context = Get-MgContext
    Write-Host ("Connected to tenant {0} as {1}" -f $context.TenantId, ($context.Account, $context.ClientId | Where-Object { $_ } | Select-Object -First 1))
}

function Invoke-IntuneGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body,

        [int]$MaxRetries = 5
    )

    if ($Uri -notmatch '^https://') {
        $Uri = "https://graph.microsoft.com/$($Uri.TrimStart('/'))"
    }

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            $params = @{ Uri = $Uri; Method = $Method; OutputType = 'PSObject'; ErrorAction = 'Stop' }
            if ($null -ne $Body) {
                if ($Body -isnot [string]) { $Body = $Body | ConvertTo-Json -Depth 50 }
                $params.Body = $Body
                $params.ContentType = 'application/json'
            }
            return Invoke-MgGraphRequest @params
        }
        catch {
            $status = $null
            $retryAfter = $null
            if ($_.Exception.Response) {
                $status = [int]$_.Exception.Response.StatusCode
                try { $retryAfter = $_.Exception.Response.Headers.RetryAfter.Delta.TotalSeconds } catch { $retryAfter = $null }
            }

            $retryable = ($status -eq 429) -or ($status -ge 500 -and $status -le 599)
            if (-not $retryable -or $attempt -ge $MaxRetries) {
                throw
            }

            if (-not $retryAfter) { $retryAfter = [math]::Min(60, [math]::Pow(2, $attempt)) }
            Write-Warning ("Graph returned {0}. Retrying in {1} seconds (attempt {2} of {3})." -f $status, $retryAfter, $attempt, $MaxRetries)
            Start-Sleep -Seconds $retryAfter
        }
    }
}

function Invoke-IntuneGraphPaged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $results = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    while ($next) {
        $response = Invoke-IntuneGraph -Uri $next -Method GET
        if ($response.PSObject.Properties.Name -contains 'value') {
            foreach ($item in $response.value) { $results.Add($item) }
            $next = $response.'@odata.nextLink'
        }
        else {
            $results.Add($response)
            $next = $null
        }
    }
    return $results
}

$script:IntuneGroupNameCache = @{}

function Get-IntuneGroupName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupId
    )

    if ($script:IntuneGroupNameCache.ContainsKey($GroupId)) {
        return $script:IntuneGroupNameCache[$GroupId]
    }

    try {
        $group = Invoke-IntuneGraph -Uri "v1.0/groups/$GroupId`?`$select=displayName"
        $name = $group.displayName
    }
    catch {
        $name = "<unresolved $GroupId>"
    }

    $script:IntuneGroupNameCache[$GroupId] = $name
    return $name
}

function ConvertTo-SafeFileName {
    param([Parameter(Mandatory)][string]$Name)
    # Use the Windows set explicitly so exports are portable between Windows, macOS and Linux.
    $clean = $Name -replace '[\\/:*?"<>|\x00-\x1F]', '_'
    $clean = $clean -replace '\s+', '_' -replace '_{2,}', '_'
    return $clean.Trim('_', '.')
}

function Format-IntuneAssignmentTarget {
    <#
        Turns a Graph assignment target into a readable string, for example:
        "Include: INT-DEV-WIN-Pilot (filter include: Corporate only)"
    #>
    param([Parameter(Mandatory)][object]$Target)

    $type = $Target.'@odata.type'
    switch -Wildcard ($type) {
        '*exclusionGroupAssignmentTarget' { $label = "Exclude: " + (Get-IntuneGroupName -GroupId $Target.groupId) }
        '*groupAssignmentTarget'          { $label = "Include: " + (Get-IntuneGroupName -GroupId $Target.groupId) }
        '*allDevicesAssignmentTarget'     { $label = "Include: All devices" }
        '*allLicensedUsersAssignmentTarget' { $label = "Include: All users" }
        default                           { $label = "Unknown target type $type" }
    }

    $filterId = $Target.deviceAndAppManagementAssignmentFilterId
    if ($filterId -and $filterId -ne '00000000-0000-0000-0000-000000000000') {
        $label += " (filter $($Target.deviceAndAppManagementAssignmentFilterType): $filterId)"
    }
    return $label
}
