<#
.SYNOPSIS
    Retrieves the list of NPrinting groups.

.DESCRIPTION
    The Get-NPGroups function retrieves the list of groups from the NPrinting server.
    It uses the Invoke-NPRequest function to send a GET request to the 'groups' endpoint of the NPrinting API.
    Optional parameters can be specified to filter the results.

.PARAMETER Limit
    Specifies the maximum number of groups to retrieve.

.PARAMETER Offset
    Specifies the number of groups to skip before starting to return results.

.EXAMPLE
    Get-NPGroups

    This example retrieves all NPrinting groups.

.EXAMPLE
    Get-NPGroups -Limit 10

    This example retrieves a maximum of 10 NPrinting groups.

.EXAMPLE
    Get-NPGroups -Limit 10 -Offset 5

    This example retrieves a maximum of 10 NPrinting groups, skipping the first 5.

.NOTES
    For more information, visit the NPrinting API documentation:
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=32

.LINK
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=32
#>
function Get-NPGroups {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = "Specifies the maximum number of groups to retrieve.")]
        [int32]$Limit,
        [Parameter(HelpMessage = "Specifies the number of groups to skip before starting to return results.")]
        [int32]$Offset
    )

    try {
        $Filter = ""
        if ($PSBoundParameters.ContainsKey('Limit')) {
            $Filter = GetNPFilter -Filter $Filter -Property "limit" -Value $Limit.ToString()
        }
        if ($PSBoundParameters.ContainsKey('Offset')) {
            $Filter = GetNPFilter -Filter $Filter -Property "offset" -Value $Offset.ToString()
        }

        # Retrieve the NPrinting Groups
        $NPGroups = Invoke-NPRequest -Path "groups$Filter" -Method Get
        return $NPGroups
    } catch {
        Write-Error "Failed to retrieve NPrinting groups: $_"
    }
}