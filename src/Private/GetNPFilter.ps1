function GetNPFilter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The property to filter by.")]
        [string]$Property,

        [Parameter(Mandatory = $true, HelpMessage = "The value to filter for.")]
        [string]$Value,

        [Parameter(Mandatory = $true, HelpMessage = "The existing filter string.")]
        [AllowEmptyString()]
        [string]$Filter
    )

    # Process the property and value for filtering
    if ($null -ne $Property -and $null -ne $Value) {
        # Replace wildcard character `*` with `%`
        $Value = $Value -replace '\*', '%'
        # URI encode the value
        $Value = [System.Web.HttpUtility]::UrlEncode($Value)

        # Determine the query separator based on the current filter
        $QuerySeparator = if ($Filter.StartsWith('?')) { '&' } else { '?' }

        # Append the new filter clause
        $Filter = "$Filter$QuerySeparator$Property=$Value"
    }

    # Return the updated filter string
    return $Filter
}
