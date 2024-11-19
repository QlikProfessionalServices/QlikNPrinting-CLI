function BuildNPURI {
    param (
        [string]$Path,
        [switch]$NPE,
        [string]$URLServerAPI,
        [string]$URLServerNPE,
        [hashtable]$QueryParameters
    )

    if ([uri]::IsWellFormedUriString($Path, [System.UriKind]::Absolute)) {
        return $Path
    }

    # Base URL depending on the NPE flag
    $BaseURL = if ($NPE) { $URLServerNPE } else { $URLServerAPI }
    $FullPath = [System.IO.Path]::Combine($BaseURL.TrimEnd('/'), $Path.TrimStart('/'))

    # Add query parameters
    if ($QueryParameters) {
        $UriBuilder = [System.UriBuilder]$FullPath
        $QueryString = [System.Web.HttpUtility]::ParseQueryString($UriBuilder.Query)
        foreach ($key in $QueryParameters.Keys) {
            if (-not $QueryString[$key]) {
                $QueryString[$key] = $QueryParameters[$key]
            }
        }
        $UriBuilder.Query = $QueryString.ToString()
        return $UriBuilder.Uri.AbsoluteUri
    }
    return $FullPath
}