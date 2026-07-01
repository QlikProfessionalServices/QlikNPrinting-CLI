<#
.SYNOPSIS
	Sends an authenticated request to the NPrinting API.
.DESCRIPTION
	Core function of the module. Builds the request URI, attaches the session
	cookies and X-XSRF-TOKEN header, serialises the body and unwraps the standard
	NPrinting { data / items } envelope. Every other Get-NP* function calls this.
.PARAMETER Path
	Absolute URL, or a path relative to the API root (or the NPE root with -NPE).
.PARAMETER Method
	HTTP method (default: Get).
.PARAMETER Data
	Request body. Hashtables/objects are converted to JSON; strings are sent as-is
	when they already look like JSON, otherwise they are JSON-encoded.
.PARAMETER Depth
	ConvertTo-Json depth for the body (default: 5).
.PARAMETER NPE
	Target the NPE (NPrinting Private Endpoint) API root instead of the standard API.
.PARAMETER Count
	NPE: number of items per page (default: -1).
.PARAMETER OrderBy
	NPE: property to order by (default: Name).
.PARAMETER Page
	NPE: page number (default: 1).
.PARAMETER OutFile
	Save the response body to this file instead of returning it.
#>
function Invoke-NPRequest {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$Path,

		[ValidateSet('Get', 'Post', 'Patch', 'Delete', 'Put')]
		[string]$Method = 'Get',

		$Data,

		[int]$Depth = 5,

		[Parameter(ParameterSetName = 'NPE')]
		[switch]$NPE,

		[Parameter(ParameterSetName = 'NPE')]
		[int]$Count = -1,

		[Parameter(ParameterSetName = 'NPE')]
		[string]$OrderBy = 'Name',

		[Parameter(ParameterSetName = 'NPE')]
		[int]$Page = 1,

		[System.IO.FileInfo]$OutFile
	)

	$NPEnv = $script:NPEnv
	if ($null -eq $NPEnv) {
		Write-Warning "No active session; attempting to establish a default connection."
		Connect-NPrinting
		$NPEnv = $script:NPEnv
	}

	if ([uri]::IsWellFormedUriString($Path, [System.UriKind]::Absolute)) {
		$uri = $Path
	}
	elseif ($NPE.IsPresent) {
		$npePath = $Path
		if (-not $npePath.Contains('count=')) {
			$sep = if ($npePath.Contains('?')) { '&' } else { '?' }
			$npePath = "$npePath$($sep)count=$Count"
		}
		if (-not $npePath.Contains('orderBy=')) {
			$npePath = "$npePath&orderBy=$OrderBy"
		}
		if (-not $npePath.Contains('page=')) {
			$npePath = "$npePath&page=$Page"
		}
		$uri = "$($NPEnv.URLServerNPE)/$npePath"
	}
	else {
		$uri = "$($NPEnv.URLServerAPI)/$Path"
	}

	$splat = @{
		URI         = $uri
		WebSession  = $NPEnv.WebRequestSession
		Method      = $Method
		ContentType = 'application/json;charset=UTF-8'
		Headers     = Get-XSRFToken
	}

	# PowerShell 7+ trusts self-signed certs per-request; 5.x is handled globally
	# in Enable-NPTrustAllCerts.
	if ($NPEnv.TrustAllCerts -and $PSVersionTable.PSVersion.Major -gt 5) {
		$splat.SkipCertificateCheck = $true
	}

	# On the first request (before any auth cookie exists) send explicit creds.
	$hasCookie = $NPEnv.WebRequestSession.Cookies.GetCookies($NPEnv.URLServerBase).Count -gt 0
	if (-not $hasCookie -and $null -ne $NPEnv.Credentials) {
		$splat.Credential = $NPEnv.Credentials
	}

	if ($null -ne $Data) {
		if ($Data -is [string]) {
			$trimmed = $Data.Trim()
			$looksJson = ($trimmed.StartsWith('{') -and $trimmed.EndsWith('}')) -or
				($trimmed.StartsWith('[') -and $trimmed.EndsWith(']'))
			$splat.Body = if ($looksJson) { $Data } else { $Data | ConvertTo-Json -Depth $Depth }
		}
		else {
			$splat.Body = $Data | ConvertTo-Json -Depth $Depth
		}
	}

	if ($PSBoundParameters.ContainsKey('OutFile')) {
		$splat.OutFile = $OutFile
	}

	# Capture response headers on PowerShell 6.1+ so create (201) responses can
	# surface the new resource id from the Location header. (Not available on
	# Windows PowerShell 5.1, where creates simply return no id.)
	$respHeaders = $null
	if ($PSVersionTable.PSVersion -ge [version]'6.1.0') {
		$splat.ResponseHeadersVariable = 'respHeaders'
	}

	if ($PSBoundParameters.Debug.IsPresent) {
		$Global:NPSplat = $splat
	}

	try {
		$result = Invoke-RestMethod @splat
	}
	catch {
		# Works for both Windows PowerShell (WebException -> HttpWebResponse) and
		# PowerShell 7 (HttpResponseException -> HttpResponseMessage).
		$ex = $_.Exception
		$resp = $ex.Response
		if ($null -ne $resp) {
			$url = if ($resp.PSObject.Properties['ResponseUri']) { $resp.ResponseUri.AbsoluteUri }
				elseif ($resp.PSObject.Properties['RequestMessage'] -and $resp.RequestMessage) { $resp.RequestMessage.RequestUri.AbsoluteUri }
				else { $uri }
			$status = if ($resp.PSObject.Properties['StatusDescription']) { $resp.StatusDescription }
				elseif ($resp.PSObject.Properties['ReasonPhrase']) { $resp.ReasonPhrase }
				else { $ex.Message }
			Write-Warning "From: $url`nResponse: $status"
		}
		Write-Error -Message "NPrinting request failed: $($ex.Message)" -Exception $ex
		return
	}

	if ($PSBoundParameters.Debug.IsPresent) {
		Write-Warning "Session XSRF Token: $(Get-XSRFToken -Raw)"
	}

	if ($PSBoundParameters.ContainsKey('OutFile')) {
		return
	}

	# Create/update/delete typically return an empty body. Surface the new id from
	# the Location header when present (POST create); otherwise return nothing.
	if ($null -eq $result -or ($result -is [string] -and [string]::IsNullOrWhiteSpace($result))) {
		if ($respHeaders -and $respHeaders['Location']) {
			$location = @($respHeaders['Location'])[0]
			return [pscustomobject]@{
				id       = ($location -split '/')[-1]
				location = $location
			}
		}
		Write-Verbose "Request returned no content."
		return
	}

	if ($NPE.IsPresent -or $null -ne $result.result) {
		$result = $result.Result
	}

	$props = @($result | Get-Member -MemberType Properties)
	if ($props.Count -eq 1 -and $null -ne $result.data) {
		if ($null -ne $result.data.items) {
			$result.data.items
		}
		else {
			$result.data
		}
	}
	else {
		$result
	}
}

# SIG # Begin signature block
# MIIfdAYJKoZIhvcNAQcCoIIfZTCCH2ECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCB4UlVZWKph1NS
# tEdXRKpNIl/Pshr8XQQQux5UqtgbhKCCGb0wggN5MIIC/qADAgECAhAcz51nzeIZ
# /xLZmv82guWnMAoGCCqGSM49BAMDMHwxCzAJBgNVBAYTAlVTMQ4wDAYDVQQIDAVU
# ZXhhczEQMA4GA1UEBwwHSG91c3RvbjEYMBYGA1UECgwPU1NMIENvcnBvcmF0aW9u
# MTEwLwYDVQQDDChTU0wuY29tIFJvb3QgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkg
# RUNDMB4XDTE5MDMwNzE5MzU0N1oXDTM0MDMwMzE5MzU0N1oweDELMAkGA1UEBhMC
# VVMxDjAMBgNVBAgMBVRleGFzMRAwDgYDVQQHDAdIb3VzdG9uMREwDwYDVQQKDAhT
# U0wgQ29ycDE0MDIGA1UEAwwrU1NMLmNvbSBDb2RlIFNpZ25pbmcgSW50ZXJtZWRp
# YXRlIENBIEVDQyBSMjB2MBAGByqGSM49AgEGBSuBBAAiA2IABOpt7gyJbfdl1TyX
# rJy6JZGueJwq39d2z/FOJTbnNRuYrlS823MWKvLp+ziKPRCumlXWYiCS5X0xZxWv
# 2FIxsD9Tf7tCm8JcqSsa6W8uRyjXT+yEBglVRcOJGZiIjeFxJKOCAUcwggFDMBIG
# A1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgwFoAUgtGFczDnNQTTjgKS++Wk0cQh
# 6M0weAYIKwYBBQUHAQEEbDBqMEYGCCsGAQUFBzAChjpodHRwOi8vd3d3LnNzbC5j
# b20vcmVwb3NpdG9yeS9TU0xjb20tUm9vdENBLUVDQy0zODQtUjEuY3J0MCAGCCsG
# AQUFBzABhhRodHRwOi8vb2NzcHMuc3NsLmNvbTARBgNVHSAECjAIMAYGBFUdIAAw
# EwYDVR0lBAwwCgYIKwYBBQUHAwMwOwYDVR0fBDQwMjAwoC6gLIYqaHR0cDovL2Ny
# bHMuc3NsLmNvbS9zc2wuY29tLWVjYy1Sb290Q0EuY3JsMB0GA1UdDgQWBBQyeLEO
# kNtGzxrPtmMRbf4w52dUMDAOBgNVHQ8BAf8EBAMCAYYwCgYIKoZIzj0EAwMDaQAw
# ZgIxAIZwNaUUH2Oi1OfK9PES0J4Ay3EIm1mAOjpxEHItL3pSmV+5tJ/iQQqK2Dwg
# evkxFQIxAIHLuf6CWo8Wvxn2XZR/+3do0Q/XjqQSbfhJlqwRUVPlxUz5aK1vpJwv
# LRHaPzhzXTCCA5owggMgoAMCAQICEGVL9aWgte+AgghPboEa/wIwCgYIKoZIzj0E
# AwMweDELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMRAwDgYDVQQHDAdIb3Vz
# dG9uMREwDwYDVQQKDAhTU0wgQ29ycDE0MDIGA1UEAwwrU1NMLmNvbSBDb2RlIFNp
# Z25pbmcgSW50ZXJtZWRpYXRlIENBIEVDQyBSMjAeFw0yNTA2MDMwNzIxMTFaFw0y
# ODA2MDIwNzIxMTFaMFIxCzAJBgNVBAYTAkFVMREwDwYDVQQIDAhWaWN0b3JpYTES
# MBAGA1UEBwwJQnJ1bnN3aWNrMQ0wCwYDVQQKDAROTmV0MQ0wCwYDVQQDDAROTmV0
# MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAEngGfAKTCECZA4Zhxz9OCOhWt6MXoHPXU
# shp0UnRnKAtpP3sLqxdectVGokuO/dG0WDX3G8STwQ0HOlOt/I142BmQQzV3Fg2N
# DxEgAiJafiHnEHCaRRycBfcu7SUAMUoXo4IBkzCCAY8wDAYDVR0TAQH/BAIwADAf
# BgNVHSMEGDAWgBQyeLEOkNtGzxrPtmMRbf4w52dUMDB5BggrBgEFBQcBAQRtMGsw
# RwYIKwYBBQUHMAKGO2h0dHA6Ly9jZXJ0LnNzbC5jb20vU1NMY29tLVN1YkNBLWNv
# ZGVTaWduaW5nLUVDQy0zODQtUjIuY2VyMCAGCCsGAQUFBzABhhRodHRwOi8vb2Nz
# cHMuc3NsLmNvbTBRBgNVHSAESjBIMAgGBmeBDAEEATA8BgwrBgEEAYKpMAEDAwEw
# LDAqBggrBgEFBQcCARYeaHR0cHM6Ly93d3cuc3NsLmNvbS9yZXBvc2l0b3J5MBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMEwGA1UdHwRFMEMwQaA/oD2GO2h0dHA6Ly9jcmxz
# LnNzbC5jb20vU1NMY29tLVN1YkNBLWNvZGVTaWduaW5nLUVDQy0zODQtUjIuY3Js
# MB0GA1UdDgQWBBTx/f9S3OD23I4gbVreRmoGuRyeKjAOBgNVHQ8BAf8EBAMCB4Aw
# CgYIKoZIzj0EAwMDaAAwZQIxAICwlRFbAJ/sRgO3UFmz6ltoHAv8Q9KeczD/2g9t
# Wb1rfVMbZLfOhUPNfFwrzjAlVgIwNWVDg2xdBz0Zxm50jDWLL3MVJRMXdmBLqDh6
# Tl1ozTY5O/jrXryFfY/4A8ChX61dMIIFcjCCA1qgAwIBAgIQdlP+uT3Z5+kmMqzW
# Cr6sODANBgkqhkiG9w0BAQwFADBTMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xv
# YmFsU2lnbiBudi1zYTEpMCcGA1UEAxMgR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcg
# Um9vdCBSNDUwHhcNMjAwMzE4MDAwMDAwWhcNNDUwMzE4MDAwMDAwWjBTMQswCQYD
# VQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEpMCcGA1UEAxMgR2xv
# YmFsU2lnbiBUaW1lc3RhbXBpbmcgUm9vdCBSNDUwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQC6dDPsJ9wSOCEbxdNhKNZavE/fi8yRhEMkV7xkIbw7HB89
# T4ytB7fzxdcC6REUgpqqtJRyO3ENGu9oa4V5jq9m6liYDbrBfHnS/82zbzFF0AV0
# BAByaid+uDc/Oojtl4P1qzVND59ZO/Uv31nFfKUydmCWyO3u+AR+GVFyqL9EQXq8
# ex47AJu8uuCWv5D+jZvDcosAEvggOmA498HMhYr7h3kuoSsg5sughZEjtsQoB1Qo
# 3uwQMU+K8s0UHx7dVRzqKDFM+SFqqM3zlmf6AUGbzQ8LaH+73vFD6hflsNxwIrNp
# Nll0a8bliSp85QuBXas/j7jRdnLzfKKp4pdBv8yMRf5hyfZsBwsABOgVI0+CKi32
# 78P6ETZIodH9ejk6NF2jLA6bd1AgNEDdsQMxrV/pYodzlgNh95Sw2VxsT+cUxeHx
# ew0jnM1wjB1q3kotiyq720IUBQeq+xTcMdP2H2zLvmhmRHBNbRf5cesFc46RknXr
# aFwe9kRhGCli3RdmiOwouklv2z53/rkxH3UcGKKmR73Y7kiFO/2z4g8/KpjGmvqC
# b7GlpYYdWjr6pGx0D3dSYWp/hyneOZuL7rNFYDAklxUSKoUwkyaslqYt6HBtC6ky
# rSybKAp2QvJVYVGYlN7t9sUXbzwVELAOrbDexRb0ZdHML1pWCM+ZxPBVkcIseQID
# AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
# FgQURrIcd+F7FfClOaFw3tHELuptst4wDQYJKoZIhvcNAQEMBQADggIBABZ8CmdK
# AzyTKj4cT0ZVsJqeiOHrU/1MVXmE+Wy2n6kKtomrVAcUFkpJWvS4LoYUxH4ZifmH
# iLzsstKVjOAM+fKUZqaYVxuh39FxfYy1+HEC3RO2vvqwMcMsZ+saGA4aTdwszzFc
# YSipneNqLK5QSw460Gn7ijRE335LjhqQCdox2sovpff0Nyw1DRpizTx7PFZ3ZZVc
# lHNwn2EvaWQjHUx5B8IXfDrtqm1xAxRiRcy3PlTYUXFC6juSQqUvVIGjsAxWWFa7
# 5JjuZscR+ahFF+JlKore4qjOxS329c6t8OMKCd1Te2ypbIZ+od42NQAPX4D9Rbtx
# ZkPURCzQuwFOmZ4+TeFeVh8FeoIdssstpTO5OeXEt9pC4b3QlEKA+hiUO5NDqMiU
# Om1+nfxPoMLT5aWqECZvBiJb4AHiSr8Z5USesK2rGdLN60fEYoHs8MJ6jUz9wiW3
# vCxwjqqtUvQUPKp4HQTTydUlgqday4x8H1cCO4cbyNf5VBodyhpLJ7HiSu/nmkAU
# T6U8n9WjvpQ1nMLXPyjupBcrQ71kp9ev6VPnp3cexRIbMeJLxn+eHO6jOpRQXaZQ
# BlJeRQMrtADgwe3YDcGuu0kJgYJaQkOvmWO4FNE8i93V8FTtcmfC9so+NYSHgA1S
# lVBB1rINGUAvthNN97Fg1HbFVzluWqJeCnncMIIGhDCCBGygAwIBAgIRAIRyP7gw
# DfuodbM7V8wmN4IwDQYJKoZIhvcNAQEMBQAwXjELMAkGA1UEBhMCQkUxGTAXBgNV
# BAoTEEdsb2JhbFNpZ24gbnYtc2ExNDAyBgNVBAMTK0dsb2JhbFNpZ24gT2ZmbGlu
# ZSBSNDUgVGltZXN0YW1waW5nIENBIDIwMjUwHhcNMjUxMDE1MDcyNDU2WhcNMzcw
# MTEwMDAwMDAwWjBdMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBu
# di1zYTEzMDEGA1UEAxMqR2xvYmFsc2lnbiBSNDUgVFNBIGZvciBBdXRoZW50aWNv
# ZGUgMjAyNTEwMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAo5qib0Lz
# OmONbaHJo3ptJ5114tIqUelWQN9js0nuN9WjqaPiWBNL5AOxM/dr0tmxVohS4Chu
# z4W2U6J3IWR+eKF19ZaRti+3qylKyGrYFaThdEnRlJ+EB1in0Irq6BSGGL7kAGOv
# iVGvH4hlnvFL4N5XhswQ3l1Ha3sXdUOCQ5AiXhZPccq60xCJjEEGLdABWJIRKU0m
# k3ngJGj7X8ryWqCxTUrA//hy2iCY5OscrNA4y+k6xrvFR3pglhgdNAATbIDnwByr
# xLp7VyaYprrUpY0wxuxc1DjRNhrKV+Xf2DK77Huj88GMem2i4WCmSrpU/G2qbl5W
# bzNN/5w9iig1KY1wg3LrHzs3c6RdJh/iHLR9Sjkc7qJLidH3QQzT8TKmZX4weJLb
# 5l17/Z53TFzQ/WO969H3MSCjRIsPJC5umBp70EK7CE3GEfFWtgvYig0hVmak3m81
# VBKI1zG5LcZxbYt3cQmJhZZaCOvcTjOaIHbYwEzQ8rOEXCHAe8rvW1GJAgMBAAGj
# ggG8MIIBuDAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgw
# DAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUpFtFrgk/9CUBPthTUQJp85AI2BYwHwYD
# VR0jBBgwFoAUdwI7ATEPHnR3w0jIwwdjVYilO6IwgaUGCCsGAQUFBwEBBIGYMIGV
# MEIGCCsGAQUFBzABhjZodHRwOi8vb2NzcC5nbG9iYWxzaWduLmNvbS9nc29mZmxp
# bmVyNDV0aW1lc3RhbXBjYTIwMjUwTwYIKwYBBQUHMAKGQ2h0dHA6Ly9zZWN1cmUu
# Z2xvYmFsc2lnbi5jb20vY2FjZXJ0L2dzb2ZmbGluZXI0NXRpbWVzdGFtcGNhMjAy
# NS5jcnQwSgYDVR0fBEMwQTA/oD2gO4Y5aHR0cDovL2NybC5nbG9iYWxzaWduLmNv
# bS9nc29mZmxpbmVyNDV0aW1lc3RhbXBjYTIwMjUuY3JsMEwGA1UdIARFMEMwQQYJ
# KwYBBAGgMgEeMDQwMgYIKwYBBQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24u
# Y29tL3JlcG9zaXRvcnkvMA0GCSqGSIb3DQEBDAUAA4ICAQBwzMXQamU+SQhZibXB
# p31NqVIF4I/z0kZD0ozcFy205DhbUAu8YViH+c82ypDkH3wk2LLrVB/T21VBcfjq
# DS9p2ormMMBCSJrOB2WBno9HckZzSUgpdPCkH9s7ynoX4RZS/UBL9M2DJVc+hpKb
# zCNmrQWhkoSTHbTk8/JFhmhiX5HPp+hiB8Pc3cX1zHLTN+uNDBoxyzJ6tkmevgal
# UWKNxCHpICYj9lrJ+bVvBDkxBgr9+bfFuamAUwK2SHW6dEtzHp55mfeTAJNIORc/
# 95V+h+QM8wFgwtpV1EVB1ze4po3pxcWjSfAZo4qEvyknEQqqf8yDmNsBmgH7qg/a
# 4NEbgnS+4QuEqLL+5hZvd+AyJh/nyNw6Rp8lXObSNvahrS23Qm6+Fy90gx2wALq8
# 6i70p+QYMcADZcO6NQABlqbGh92BzaLYXo7RlC6vMikqGjLgJe4KC5dfiA5E/uEI
# seLYcD2e4RbL/jHs4TGU91Osx3O+S+2dEl65H2HZADgVLJETeXZDvUe4WBOiN6Zw
# mVf9mIBjvHwt4f6GHWcWg5ZYakjdoW+eHKet5xRzkUAJP/wCRCcX9QiyB9WCOLwR
# WmTycPaLhLO6gt1JgaT8xsX97eVfaJXs6mkMSzUkz+t++6KWyKOctzAVozo11N9r
# l4BtPJXVW5VyQTV+bJ059TGLoTCCBqAwggSIoAMCAQICEQCD2oY3t58MhAyUe4QK
# UngfMA0GCSqGSIb3DQEBDAUAMFMxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i
# YWxTaWduIG52LXNhMSkwJwYDVQQDEyBHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBS
# b290IFI0NTAeFw0yNTA3MTYwMzA1MDRaFw00MTA3MTYwMDAwMDBaMF4xCzAJBgNV
# BAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTQwMgYDVQQDEytHbG9i
# YWxTaWduIE9mZmxpbmUgUjQ1IFRpbWVzdGFtcGluZyBDQSAyMDI1MIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEApHcW+O19i+LdAoZFYzS+5X+WYvnWoFqX
# Afir1hynhUTdH4RW1Db+yOmrQ275jlsQ6bzoZ3nN0CMncZX4E0Qhpp6Qvx27+flp
# fzeMQacD7VciWUiF3TLiu7wT2bBCSENUn3hfGMG4PJvYFvO5o4DA1iNvHhG4oSzc
# todoJfb4c8EjVahCw/NLizB3ra+NWe2gZBSaZKraMxFt676yqx7RcQnjbF4R0OLG
# ovsZt23vU69A5BdoPxdA9zu9rM+qTBsPDVUJexYwEVU0GY7BJ5mUWWniyAPHW0Wv
# 4Azk5t7I0XUIjA3+2OGkr0dVBXVBDyEeGBVrYXEdhfVLwuh6HBGJFdIrEY5KoGlp
# oT+4BBQe4XCH5sv15Uo+M72VKWjPA5Ex3nfFJC4P5FW1SR6olCSaIrtnZzc+zgmp
# SyiD+GcE2udQRQHbDi74enXgazk0+ktpHZ1Z8oTvSaSIREovXSLbH3KC8uFIkXuc
# l7XPH7ZGIrmF9eF4zuoo5FIUnsvV60kLqFDzPk+UbLmgZDUCPlFFBBehaaNvixEy
# mx9ON2KXev+MfK6OZChqGbrOC2wvvAFHyKlTZbVHdqNiu0u5a2T1C9dSTRny1/hx
# LwcxL9BWPzQLwhsiyXqUzM7uD0lD9+PYMaxUYgoVSxqb4xvPCiVqLNabI+WtjEzY
# fQ0P+6tBTFsCAwEAAaOCAWIwggFeMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDCDASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBR3AjsBMQ8e
# dHfDSMjDB2NViKU7ojAfBgNVHSMEGDAWgBRGshx34XsV8KU5oXDe0cQu6m2y3jCB
# jgYIKwYBBQUHAQEEgYEwfzA3BggrBgEFBQcwAYYraHR0cDovL29jc3AuZ2xvYmFs
# c2lnbi5jb20vdGltZXN0YW1wcm9vdHI0NTBEBggrBgEFBQcwAoY4aHR0cDovL3Nl
# Y3VyZS5nbG9iYWxzaWduLmNvbS9jYWNlcnQvdGltZXN0YW1wcm9vdHI0NS5jcnQw
# PwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC5nbG9iYWxzaWduLmNvbS90aW1l
# c3RhbXByb290cjQ1LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEM
# BQADggIBADKj7n7RbuRmMZZYXqlMPRJoR6X1n//quXGLVfOpFoR9Ya05L94w0ywB
# jelyGGf+nAB+CZFQ7gUOd2a2bpfpW8Xw5ArM+YjPEf8AtC4E6Yr105U1YNjlTSER
# oWJKc1hkSN5m4dpsYteFykzFQVwX50hYKH3yZ6Vcu6Ha0EA5ofzLpi2jK2jbRDCX
# bFNLi5mO1xKRdB2AzAF0f5C00b4H3d5sCOB8njTvAwaTMGEMeTkLWM4Z9Y+3UOtO
# po1QuxXbDpXVkLXraG25iL1VtvjxEAy4534nUINB9whORicJJSTLba6fOK2f/1QG
# WEdewWLHAzE+N5oH0QoNRALpJ5JjIfeInvO+sQdBidnPuLKJ95HTj7XyMvJhFZjt
# bHJGlEWx4UgKcuNKLDLXWALfwQDN2Dey3kTfd4yw4nQdk1PctLLK3F4L2nnLv94B
# MkpY+Rfl53oOEN4yTvtwCYP+VDuZrktc7NacoTVxZnKGkv8a1akckdOwQZC+i8Ay
# 1VyzMAX/Tb4+r3c65B7cpAtq3OoUijXUJgvZxci6TX78smL2TYy2tWn+8G4krnXv
# y2ELR2XYnKEOS4MVmrSCsjM5nxSrghE10VDXQbEfa93lhikfFoIuINKzWDLqvu8Z
# ucmxEufxpHjNnnRVXX/Zv5KQq8pu/MQoOz6DC74n5+O5bSwvT5sgMYIFDTCCBQkC
# AQEwgYwweDELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMRAwDgYDVQQHDAdI
# b3VzdG9uMREwDwYDVQQKDAhTU0wgQ29ycDE0MDIGA1UEAwwrU1NMLmNvbSBDb2Rl
# IFNpZ25pbmcgSW50ZXJtZWRpYXRlIENBIEVDQyBSMgIQZUv1paC174CCCE9ugRr/
# AjANBglghkgBZQMEAgEFAKBqMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAdJU9a
# hnlnNQ5MMtPKm7ZqgXd0hDkO1XJmEPM4x9ldYjAKBggqhkjOPQQDAgRmMGQCMDLb
# 93SYBrtBbbYtsYva8J+Wu/RfKuuq3QMEXmrpZtXRtYjlPc2qU53f4ebBIbJJFwIw
# A2d/3UidwSIHGepGzWscD2pN0JJsGgu04YwOzspwS9rjXN7yauvgAaQy4JyeYWQl
# oYIDhDCCA4AGCSqGSIb3DQEJBjGCA3EwggNtAgEBMHMwXjELMAkGA1UEBhMCQkUx
# GTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExNDAyBgNVBAMTK0dsb2JhbFNpZ24g
# T2ZmbGluZSBSNDUgVGltZXN0YW1waW5nIENBIDIwMjUCEQCEcj+4MA37qHWzO1fM
# JjeCMAsGCWCGSAFlAwQCAqCCAVEwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAc
# BgkqhkiG9w0BCQUxDxcNMjYwNzAxMTQ0NjExWjArBgkqhkiG9w0BCTQxHjAcMAsG
# CWCGSAFlAwQCAqENBgkqhkiG9w0BAQwFADA/BgkqhkiG9w0BCQQxMgQwz01sknhU
# WpvO/YQuxqBx2H2DlL1ePRowLJa8ld1FfD/cs0axqktWPG7gsQNHrcxIMIGoBgsq
# hkiG9w0BCRACDDGBmDCBlTCBkjCBjwQUHSS/Gatriz8ckaZYxdNUZIEjnS4wdzBi
# pGAwXjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExNDAy
# BgNVBAMTK0dsb2JhbFNpZ24gT2ZmbGluZSBSNDUgVGltZXN0YW1waW5nIENBIDIw
# MjUCEQCEcj+4MA37qHWzO1fMJjeCMA0GCSqGSIb3DQEBDAUABIIBgEUNJo666vOH
# qZYqpKUIpSX7cYfxziCl7qoJXpygPsYzCxBX2Pu+VBJz/iMlByZsJVBu8Icc5CcQ
# i11EWC2UuLmvN6p84N5cKKtXCLAsdiiXCLibVx/6Kxdk0hW2oVOaDhWudPgf2MF3
# tL9quNBjtgWYKvv3ShSe5Nz7J7E01HmOwNJosQMuBF7y4RpMTviMczgvuDGpLY7G
# ZjZNe7VfkZYNGjnso2xIFEF7IIhJ055n4ZTBcz0tasaYKnZ4lxesg9GeqjRKMH44
# dMxE0vXMhBFqqGZc9QhbQzBZ1P6L3tPkuu5HTWNuOF3MSXN/Y/RAUecbBtGuCZUz
# 0fEQrT03dMSpFWEnTwgu1nu6cRJF7vX8hTGjIjKlR7DtcRPohSqHOy8AvTFZgDzb
# BHNKuNHwfrBRkbAyc9Ogmxk2hitAetEdagsrNDYQSw1wd4o0dDgQSBeBFDvuwrht
# oCkfVaPMHvLx1M54B3o7pKvdQhQ14f2Hpd9QkcqSNN65X973mRE66w==
# SIG # End signature block
