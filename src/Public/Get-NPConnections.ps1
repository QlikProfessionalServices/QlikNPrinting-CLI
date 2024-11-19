<#
.SYNOPSIS
    Retrieves the list of NPrinting connections.

.DESCRIPTION
    The Get-NPConnections function retrieves the list of connections from the NPrinting server.
    It uses the Invoke-NPRequest function to send a GET request to the 'connections' endpoint of the NPrinting API.

.EXAMPLE
    Get-NPConnections

    This example retrieves all NPrinting connections.

.NOTES
    For more information, visit the NPrinting API documentation:
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=19#Connections

.LINK
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=19#Connections
#>
function Get-NPConnections {
    [CmdletBinding()]
    param()
    try {
        # Retrieve the NPrinting Connections
        $NPConnections = Invoke-NPRequest -Path 'connections' -Method Get
        return $NPConnections
    } catch {
        Write-Error "Failed to retrieve NPrinting connections: $_"
    }
}