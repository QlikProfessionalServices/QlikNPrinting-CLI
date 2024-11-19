function AuthenticateNPrinting {
	param (
		[string]$AuthScheme,
		[pscredential]$Credentials
	)
    
	$LoginUrl = if ($AuthScheme -eq 'NPrinting') {
		"$($script:NPEnv.URLServerBase)/login"
	} else {
		"$($script:NPEnv.URLServerAPI)/login/$AuthScheme"
	}
		
	Write-Verbose "Authenticating to $LoginUrl"
	if ($AuthScheme -eq 'NPrinting' -and $Credentials) {
		$Body = @{
			username = $Credentials.UserName
			password = $Credentials.GetNetworkCredential().Password
		} | ConvertTo-Json -Depth 3
		
		return Invoke-NPRequest -Path $LoginUrl -method 'Post' -Data $Body
	}
		
	return Invoke-NPRequest -Path $LoginUrl -method 'Get'
}
	