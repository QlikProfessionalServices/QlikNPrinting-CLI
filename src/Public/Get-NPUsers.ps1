<#
.SYNOPSIS
    Retrieves the list of NPrinting users.

.DESCRIPTION
    The Get-NPUsers function retrieves the list of users from the NPrinting server.
    It uses the Invoke-NPRequest function to send a GET request to the 'users' endpoint of the NPrinting API.
    Optional parameters can be specified to filter the results.

.PARAMETER ID
    Specifies the ID of the user to retrieve.

.PARAMETER Name
    Specifies the name of the user to filter the results.

.PARAMETER Email
    Specifies the email of the user to filter the results.

.PARAMETER Role
    Specifies the role of the user to filter the results.

.PARAMETER Offset
    Specifies the number of users to skip before starting to return results.

.PARAMETER Limit
    Specifies the maximum number of users to retrieve.

.PARAMETER Filters
    Specifies whether to include filter details for the user.

.PARAMETER Groups
    Specifies whether to include group details for the user.

.PARAMETER Roles
    Specifies whether to include role details for the user.

.EXAMPLE
    Get-NPUsers

    This example retrieves all NPrinting users.

.EXAMPLE
    Get-NPUsers -ID "12345"

    This example retrieves the NPrinting user with the specified ID.

.EXAMPLE
    Get-NPUsers -Name "John Doe"

    This example retrieves all NPrinting users with the name "John Doe".

.EXAMPLE
    Get-NPUsers -Email "john.doe@example.com"

    This example retrieves all NPrinting users with the specified email.

.EXAMPLE
    Get-NPUsers -Role "Admin"

    This example retrieves all NPrinting users with the specified role.

.EXAMPLE
    Get-NPUsers -Limit 10 -Offset 5

    This example retrieves a maximum of 10 NPrinting users, skipping the first 5.

.EXAMPLE
    Get-NPUsers -ID "12345" -Filters

    This example retrieves the filters for the NPrinting user with the specified ID.

.EXAMPLE
    Get-NPUsers -ID "12345" -Groups

    This example retrieves the groups for the NPrinting user with the specified ID.

.EXAMPLE
    Get-NPUsers -ID "12345" -Roles

    This example retrieves the roles for the NPrinting user with the specified ID.

.NOTES
    For more information, visit the NPrinting API documentation:
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=63

.LINK
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=63
#>
function Get-NPUsers {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'ByID', Mandatory = $true, HelpMessage = 'Specifies the ID of the user to retrieve.')]
        [Parameter(ParameterSetName = 'Filters', Mandatory = $true, HelpMessage = 'Specifies the ID of the user to retrieve.')]
        [Parameter(ParameterSetName = 'Groups', Mandatory = $true, HelpMessage = 'Specifies the ID of the user to retrieve.')]
        [Parameter(ParameterSetName = 'Roles', Mandatory = $true, HelpMessage = 'Specifies the ID of the user to retrieve.')]
        [string]$ID,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the name of the user to filter the results.')]
        [string]$Name,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the email of the user to filter the results.')]
        [string]$Email,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the role of the user to filter the results.')]
        [string]$Role,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the number of users to skip before starting to return results.')]
        [int32]$Offset,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the maximum number of users to retrieve.')]
        [int32]$Limit,

        [Parameter(ParameterSetName = 'Filters', Mandatory = $true, HelpMessage = 'Specifies whether to include filter details for the user.')]
        [switch]$Filters,
        
        [Parameter(ParameterSetName = 'Groups', Mandatory = $true, HelpMessage = 'Specifies whether to include group details for the user.')]
        [switch]$Groups,

        [Parameter(ParameterSetName = 'Roles', Mandatory = $true, HelpMessage = 'Specifies whether to include role details for the user.')]
        [switch]$Roles
    )

    try {
        # Construct the base path
        $BasePath = 'users'
        if ($ID) { 
            $APIPath = "$BasePath/$ID" 
            if ($Filters) {
                $FiltersPath = "$APIPath/filters"
                Write-Verbose "Fetching filters for user ID: $ID"
                return Invoke-NPRequest -Path $FiltersPath -Method Get -Verbose:$VerbosePreference
            }
            if ($Groups) {
                $GroupsPath = "$APIPath/groups"
                Write-Verbose "Fetching groups for user ID: $ID"
                return Invoke-NPRequest -Path $GroupsPath -Method Get -Verbose:$VerbosePreference
            }
            if ($Roles) {
                $RolesPath = "$APIPath/roles"
                Write-Verbose "Fetching roles for user ID: $ID"
                return Invoke-NPRequest -Path $RolesPath -Method Get -Verbose:$VerbosePreference
            }
        } else {
            $Filter = ''
            if ($PSBoundParameters.ContainsKey('Name')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'name' -Value $Name
            }
            if ($PSBoundParameters.ContainsKey('Email')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'email' -Value $Email
            }
            if ($PSBoundParameters.ContainsKey('Role')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'role' -Value $Role
            }
            if ($PSBoundParameters.ContainsKey('Offset')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'offset' -Value $Offset.ToString()
            }
            if ($PSBoundParameters.ContainsKey('Limit')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'limit' -Value $Limit.ToString()
            }
            $APIPath = "$BasePath$Filter"
        }
        Write-Verbose "Request Path: $APIPath"

        # Fetch users from the API
        $NPUsers = Invoke-NPRequest -Path $APIPath -Method Get -Verbose:$VerbosePreference

        return $NPUsers
        
    } catch {
        Write-Error "Failed to retrieve NPUsers: $_"
    }
}