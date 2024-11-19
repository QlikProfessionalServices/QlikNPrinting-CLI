
function GetXSRFToken {
	[CmdletBinding()]
	param (
		[Parameter(HelpMessage = 'Return only the raw token value instead of the header dictionary.')]
		[switch]$Raw
	)

	try {
		# Retrieve the XSRF token from the cookies
		$Token = $script:NPEnv.WebRequestSession.Cookies.GetCookies($script:NPEnv.URLServerBase) | Where-Object { $_.Name -eq 'NPWEBCONSOLE_XSRF-TOKEN' }
		
		# Return the raw token value or header dictionary based on the Raw parameter
		if ($Raw) {
			return $Token.Value
		} else {
			# Create a header dictionary with the token
			$Header = [System.Collections.Generic.Dictionary[String, String]]::new()
			$Header.Add('X-XSRF-TOKEN', $Token.Value)
			return $Header
		}
	} catch {
		Write-Error "Failed to retrieve XSRF token: $_"
	}
}
