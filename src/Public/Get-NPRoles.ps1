<#
.SYNOPSIS
    Retrieves the list of NPrinting roles.

.DESCRIPTION
    The Get-NPRoles function retrieves the list of roles from the NPrinting server.
    It uses the Invoke-NPRequest function to send a GET request to the 'roles' endpoint of the NPrinting API.
    Optional parameters can be specified to filter the results.

.PARAMETER appId
    Specifies the ID of the app to filter the roles.

.PARAMETER roleName
    Specifies the name of the role to filter the results.

.PARAMETER enabled
    Specifies whether to filter the roles by their enabled status.

.PARAMETER offset
    Specifies the number of roles to skip before starting to return results.

.PARAMETER limit
    Specifies the maximum number of roles to retrieve.

.EXAMPLE
    Get-NPRoles

    This example retrieves all NPrinting roles.

.EXAMPLE
    Get-NPRoles -appId "12345"

    This example retrieves all NPrinting roles for the specified app ID.

.EXAMPLE
    Get-NPRoles -roleName "Admin"

    This example retrieves all NPrinting roles with the name "Admin".

.EXAMPLE
    Get-NPRoles -enabled $true

    This example retrieves all enabled NPrinting roles.

.EXAMPLE
    Get-NPRoles -limit 10 -offset 5

    This example retrieves a maximum of 10 NPrinting roles, skipping the first 5.

.NOTES
    For more information, visit the NPrinting API documentation:
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=50

.LINK
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=50
#>
function Get-NPRoles {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = 'Specifies the number of roles to skip before starting to return results.')]
        [int32]$offset,
        [Parameter(HelpMessage = 'Specifies the maximum number of roles to retrieve.')]
        [int32]$limit,
        [Parameter(HelpMessage = 'Specifies the ID of the app to filter the roles.')]
        [string]$appId,
        [Parameter(HelpMessage = 'Specifies the name of the role to filter the results.')]
        [string]$roleName,
        [Parameter(HelpMessage = 'Specifies whether to filter the roles by their enabled status.')]
        [bool]$enabled
    )

    try {
        $Filter = ''
        if ($PSBoundParameters.ContainsKey('appId')) {
            $Filter = GetNPFilter -Filter $Filter -Property 'appId' -Value $appId
        }
        if ($PSBoundParameters.ContainsKey('roleName')) {
            $Filter = GetNPFilter -Filter $Filter -Property 'roleName' -Value $roleName
        }
        if ($PSBoundParameters.ContainsKey('enabled')) {
            $Filter = GetNPFilter -Filter $Filter -Property 'enabled' -Value $enabled.ToString()
        }
        if ($PSBoundParameters.ContainsKey('offset')) {
            $Filter = GetNPFilter -Filter $Filter -Property 'offset' -Value $offset.ToString()
        }
        if ($PSBoundParameters.ContainsKey('limit')) {
            $Filter = GetNPFilter -Filter $Filter -Property 'limit' -Value $limit.ToString()
        }

        # Retrieve the NPrinting Roles
        $NPRoles = Invoke-NPRequest -Path "roles$Filter" -method Get
        return $NPRoles
    } catch {
        Write-Error "Failed to retrieve NPRoles: $_"
    }
}