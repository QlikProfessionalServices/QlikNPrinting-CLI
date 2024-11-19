<#
.SYNOPSIS
    Sends a request to the NPrinting API.

.DESCRIPTION
    The Invoke-NPRequest function sends a request to the NPrinting API.
    It supports various HTTP methods and can handle different types of requests, including those for NPrinting Private Endpoints (NPE).

.PARAMETER Path
    Specifies the API endpoint path.

.PARAMETER Method
    Specifies the HTTP method to use for the request. Valid values are 'Get', 'Post', 'Patch', 'Delete', and 'Put'.

.PARAMETER Data
    Specifies the data to send with the request, if applicable.

.PARAMETER NPE
    Indicates that the request is for NPrinting Private Endpoints.

.PARAMETER Count
    Specifies the number of items to retrieve for NPE requests.

.PARAMETER OrderBy
    Specifies the field by which to order the results for NPE requests.

.PARAMETER Page
    Specifies the page number to retrieve for NPE requests.

.PARAMETER OutFile
    Specifies the file to which the response should be written for download requests.

.PARAMETER InFile
    Specifies the file to upload for upload requests.

.EXAMPLE
    Invoke-NPRequest -Path 'connections' -Method Get

    This example sends a GET request to the 'connections' endpoint of the NPrinting API.

.EXAMPLE
    Invoke-NPRequest -Path 'reports' -Method Post -Data $reportData

    This example sends a POST request to the 'reports' endpoint of the NPrinting API with the specified data.

.EXAMPLE
    Invoke-NPRequest -Path 'tasks' -Method Get -NPE -Count 10 -OrderBy 'Name' -Page 2

    This example sends a GET request to the 'tasks' endpoint of the NPrinting API for NPrinting Private Endpoints, retrieving 10 items ordered by 'Name' on page 2.

.NOTES
    For more information, visit the NPrinting API documentation.

#>
function Invoke-NPRequest {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [ValidateSet('Get', 'Post', 'Patch', 'Delete', 'Put')]
        [string]$Method = 'Get',

        $Data,

        [Parameter(ParameterSetName = 'NPE')]
        [Parameter(ParameterSetName = 'NPEDownload')]
        [Parameter(ParameterSetName = 'NPEUpload')]
        [switch]$NPE,

        [Parameter(ParameterSetName = 'NPE')]
        [Parameter(ParameterSetName = 'NPEDownload')]
        [Parameter(ParameterSetName = 'NPEUpload')]
        [int]$Count = -1,

        [Parameter(ParameterSetName = 'NPE')]
        [Parameter(ParameterSetName = 'NPEDownload')]
        [Parameter(ParameterSetName = 'NPEUpload')]
        [string]$OrderBy = 'Name',

        [Parameter(ParameterSetName = 'NPE')]
        [Parameter(ParameterSetName = 'NPEDownload')]
        [Parameter(ParameterSetName = 'NPEUpload')]
        [int]$Page = 1,

        [Parameter(ParameterSetName = 'NPEDownload', Mandatory = $true)]
        [System.IO.FileInfo]$OutFile,

        [Parameter(ParameterSetName = 'NPEUpload', Mandatory = $true)]
        [System.IO.FileInfo]$InFile
    )

    $NPEnv = $script:NPEnv
    if (-not $NPEnv) {
        Write-Warning 'Attempting to establish Default connection'
        Connect-NPrinting
    }

    # Build query parameters
    $QueryParameters = @{}
    if ($NPE -and (-not $PSBoundParameters.ContainsKey('Infile') -and $PSBoundParameters.ContainsKey('Outfile'))) {
        if ($Count -ne -1) { $QueryParameters['count'] = $Count }
        if ($OrderBy) { $QueryParameters['orderBy'] = $OrderBy }
        $QueryParameters['page'] = $Page
    }

    # Build URI
    $URI = BuildNPURI -Path $Path -NPE:$NPE -URLServerAPI $NPEnv.URLServerAPI -URLServerNPE $NPEnv.URLServerNPE -QueryParameters $QueryParameters

    # Splat for Invoke-RestMethod
    $SplatRest = @{
        URI         = $URI
        WebSession  = $NPEnv.WebRequestSession
        Method      = $Method
        ContentType = 'application/json;charset=UTF-8'
        Headers     = GetXSRFToken
    }

    # Add credentials if session is invalid
    if ([string]::IsNullOrEmpty($NPEnv.WebRequestSession.Cookies.GetCookies($NPEnv.URLServerAPI)) -and $NPEnv.Credentials) {
        $SplatRest['Credential'] = $NPEnv.Credentials
    }

    # Add JSON body if data exists
    if ($Data) {
        $JsonData = if ($Data -is [string]) { $Data } else { ConvertTo-Json -InputObject $Data -Depth 5 }
        $SplatRest['Body'] = $JsonData
    }

    # Handle file upload/download
    if ($OutFile) { $SplatRest['OutFile'] = $OutFile }
    if ($InFile) {
        #        
        if ($InFile.Extension -eq '.zip') { 
            # Define the boundary
            $boundary = '-----------------------------' + [System.Guid]::NewGuid().ToString('N')
            
            # Create the Content-Type header with the boundary
            $SplatRest.contentType = "multipart/form-data; boundary=$boundary"
        
            # Read the file content as bytes
            $fileBytes = [System.IO.File]::ReadAllBytes($InFile.FullName)

            # Convert the bytes to a Base64 string
            $fileContent = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($fileBytes)

            # Now construct your body
            $body = @"
--$boundary
Content-Disposition: form-data; name="file"; filename="$($InFile.Name)"
Content-Type: application/x-zip-compressed

$fileContent
--$boundary--
"@
            $SplatRest['Body'] = $body
        } else {
            $SplatRest['InFile'] = $InFile 
        }
    }

    # Debug output
    if ($PSBoundParameters.Debug.IsPresent) {
        Write-Warning "Debug: $($SplatRest | Out-String)"
    }

    # Invoke the request
    try {
        $Result = Invoke-RestMethod @SplatRest
    } catch {
        Write-Warning "Error during REST call: $($_.Exception.Message)"
        Write-Warning "From: $($_.Exception.Response.ResponseUri.AbsoluteUri) `nResponse: $($_.Exception.Response.StatusDescription)"
        return $_
    }

    # Handle the result
    if ($OutFile) { return }
    elseif ($Result) {
        if ($NPE -and $Result.result) { return $Result.result }
        if ($Result.data) {
            if ($Result.data.items) { return $Result.data.items } else { return $Result.data }
        }
        return $Result
    } else {
        Write-Error 'No results received'
    }
}