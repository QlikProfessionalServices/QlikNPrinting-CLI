<#
.SYNOPSIS
    Creates an authenticated session token.

.DESCRIPTION
    Connect-NPrinting initializes the `$Script:NPEnv` variable, 
    which is used for authenticated requests to the NPrinting server.

.PARAMETER Prefix
    The protocol prefix (http or https).

.PARAMETER Computer
    The NPrinting server hostname or IP address.

.PARAMETER Port
    The port to connect to (default: 4993).

.PARAMETER Return
    If specified, returns the authenticated user ID.

.PARAMETER Credentials
    The credentials to use for authentication.

.PARAMETER TrustAllCertificates
    If specified, bypasses SSL certificate validation.

.PARAMETER AuthScheme
    Authentication scheme (ntlm or NPrinting).

.EXAMPLE
    Connect-NPrinting -Computer 'nprinting-server' -Credentials (Get-Credential)

    This example connects to the NPrinting server using the specified credentials.

.EXAMPLE
    Connect-NPrinting -Computer 'nprinting-server' -TrustAllCertificates

    This example connects to the NPrinting server and bypasses SSL certificate validation.

.NOTES
    For more information, visit the NPrinting API documentation.

#>
function Connect-NPrinting {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[Parameter(ParameterSetName = 'Default')]
		[Parameter(ParameterSetName = 'Creds')]
		[ValidateSet('http', 'https')]
		[string]$Prefix = 'https',
		
		[Parameter(ParameterSetName = 'Default')]
		[Parameter(ParameterSetName = 'Creds')]
		[string]$Computer = $env:COMPUTERNAME,
		
		[Parameter(ParameterSetName = 'Default')]
		[Parameter(ParameterSetName = 'Creds')]
		[string]$Port = '4993',
		
		[Parameter(ParameterSetName = 'Default')]
		[Parameter(ParameterSetName = 'Creds')]
		[switch]$Return,
		
		[Parameter(ParameterSetName = 'Creds', Mandatory = $true)]
		[pscredential]$Credentials,
		
		[Parameter(ParameterSetName = 'Default')]
		[Parameter(ParameterSetName = 'Creds')]
		[Alias('TrustAllCerts')]
		[switch]$TrustAllCertificates,
		
		[Parameter(ParameterSetName = 'Default')]
		[Parameter(ParameterSetName = 'Creds')]
		[ValidateSet('ntlm', 'NPrinting')]
		[string]$AuthScheme = 'ntlm'
	)
		
	# Enforce dynamic validation for NPrinting AuthScheme
	if ($AuthScheme -eq 'NPrinting' -and $PSCmdlet.ParameterSetName -ne 'Creds') {
		throw "Credentials are mandatory when AuthScheme is set to 'NPrinting'. Please use the 'Creds' parameter set."
	}
		
	# Define API paths
	$APIPath = 'api'
	$APIVersion = 'v1'
		
	# Trust all certificates if specified
	if ($TrustAllCertificates) {
		SetTrustAllCertificates
		Write-Verbose 'TrustAllCertificates enabled'
	}
		
	# Validate local service if connecting to localhost
	if ($Computer -eq $env:COMPUTERNAME) {
		try {
			Get-Service -Name 'QlikNPrintingWebEngine' -ErrorAction Stop | Out-Null
		} catch {
			Write-Error "Local service 'QlikNPrintingWebEngine' is not running."
			return
		}
	}
		
	# Parse Computer parameter for protocol and port
	if ($Computer -match ':') {
		if ($Computer -match '^http') {
			$Prefix, $Computer = $Computer -split '://'
		}
		if ($Computer -match ':') {
			$Computer, $Port = $Computer -split ':'
		}
	}
		
	# Initialize environment
	$CookieContainer = New-Object System.Net.CookieContainer
	# Construct base URL
	$BaseURL = "$($Prefix)://$($Computer):$($Port)"
	
	# Initialize the NPEnv hash table
	$script:NPEnv = @{
		TrustAllCertificates = $TrustAllCertificates
		Prefix            = $Prefix
		Computer          = $Computer
		Port              = $Port
		API               = $APIPath
		APIVersion        = $APIVersion
		URLServerBase     = $BaseURL
		URLServerAPI      = "$BaseURL/$APIPath/$APIVersion"
		URLServerNPE      = "$BaseURL/npe"
		WebRequestSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
	}
	
	$script:NPEnv.WebRequestSession.UserAgent = 'Windows'
	$script:NPEnv.WebRequestSession.Cookies = $CookieContainer
		
	# Handle authentication based on parameter set
	switch ($PSCmdlet.ParameterSetName) {
		'Default' {
			$script:NPEnv.WebRequestSession.UseDefaultCredentials = $true
		}
		'Creds' {
			$script:NPEnv.WebRequestSession.Credentials = $Credentials
		}
	}
		
	# Authenticate and get token
	$AuthToken = AuthenticateNPrinting -AuthScheme $AuthScheme -Credentials $Credentials
		
	# Return token if requested
	if ($Return) {
		return $AuthToken
	}
}
		
