<#
.SYNOPSIS
    Retrieves the list of NPrinting filters.

.DESCRIPTION
    The Get-NPFilters function retrieves the list of filters from the NPrinting server.
    It uses the Invoke-NPRequest function to send a GET request to the 'filters' endpoint of the NPrinting API.

.EXAMPLE
    Get-NPFilters

    This example retrieves all NPrinting filters.

.NOTES
    For more information, visit the NPrinting API documentation:
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=26

.LINK
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=26
#>
function Get-NPFilters {
    [CmdletBinding()]
    param (
    )

    try {
        # Retrieve and update the global NPFilters variable
        $NPFilters = Invoke-NPRequest -Path 'filters' -Method Get
        return $NPFilters
    } catch {
        Write-Error "Failed to retrieve NPFilters: $_"
    }
}