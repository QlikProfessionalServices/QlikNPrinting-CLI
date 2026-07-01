#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
<#
	Pester tests for QlikNPrinting-CLI.
	No live NPrinting server is required: Invoke-RestMethod is mocked at the
	module boundary so request construction and response handling are verified
	in isolation.

	Run:  Invoke-Pester -Path .\tests
#>

BeforeAll {
	$script:ModuleRoot = Split-Path -Parent $PSScriptRoot
	Import-Module (Join-Path $ModuleRoot 'QlikNPrinting-CLI.psd1') -Force

	function New-TestSession {
		# Seeds a fake $script:NPEnv so Invoke-NPRequest can run without connecting.
		InModuleScope QlikNPrinting-CLI {
			$script:NPEnv = @{
				TrustAllCerts     = $false
				Prefix            = 'https'
				Computer          = 'srv'
				Port              = '4993'
				API               = 'api'
				APIVersion        = 'v1'
				URLServerBase     = 'https://srv:4993'
				URLServerAPI      = 'https://srv:4993/api/v1'
				URLServerNPE      = 'https://srv:4993/npe'
				WebRequestSession = (New-Object Microsoft.PowerShell.Commands.WebRequestSession)
			}
		}
	}
}

Describe 'Module surface' {
	It 'has a valid manifest' {
		$m = Test-ModuleManifest (Join-Path $ModuleRoot 'QlikNPrinting-CLI.psd1')
		$m.Version | Should -Not -BeNullOrEmpty
	}

	It 'exports exactly the functions under src/Public' {
		$expected = Get-ChildItem (Join-Path $ModuleRoot 'src\Public') -Filter *.ps1 |
			Select-Object -ExpandProperty BaseName | Sort-Object
		(Get-Command -Module QlikNPrinting-CLI).Name | Sort-Object | Should -Be $expected
	}

	It 'exports the core functions' {
		$core = 'Connect-NPrinting', 'Invoke-NPRequest', 'Get-NPUsers', 'New-NPUser',
			'Set-NPUser', 'Remove-NPUser', 'New-NPFilter', 'Get-NPConnections',
			'Start-NPTask', 'New-NPOnDemandRequest'
		$names = (Get-Command -Module QlikNPrinting-CLI).Name
		foreach ($c in $core) { $names | Should -Contain $c }
	}

	It 'does not export private helpers' {
		foreach ($p in 'Add-NPProperty', 'Add-NPQueryParameter', 'Get-XSRFToken', 'Enable-NPTrustAllCerts') {
			Get-Command -Module QlikNPrinting-CLI -Name $p -ErrorAction SilentlyContinue |
				Should -BeNullOrEmpty
		}
	}
}

Describe 'Add-NPQueryParameter' {
	It 'starts a query string with ?' {
		InModuleScope QlikNPrinting-CLI {
			Add-NPQueryParameter -QueryString '' -Name 'limit' -Value '10' | Should -Be '?limit=10'
		}
	}

	It 'appends with & once a query already exists' {
		InModuleScope QlikNPrinting-CLI {
			Add-NPQueryParameter -QueryString '?limit=10' -Name 'name' -Value 'x' |
				Should -Be '?limit=10&name=x'
		}
	}

	It 'translates the * wildcard to %' {
		InModuleScope QlikNPrinting-CLI {
			Add-NPQueryParameter -QueryString '' -Name 'name' -Value 'Mar*' | Should -Be '?name=Mar%'
		}
	}
}

Describe 'Get-XSRFToken' {
	It 'throws when there is no active session' {
		InModuleScope QlikNPrinting-CLI {
			$script:NPEnv = $null
			{ Get-XSRFToken } | Should -Throw '*Connect-NPrinting*'
		}
	}
}

Describe 'Invoke-NPRequest' {
	BeforeEach { New-TestSession }

	It 'builds an absolute URI from a relative API path' {
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod { [pscustomobject]@{ ok = $true } }
		Invoke-NPRequest -Path 'users' -Method Get | Out-Null
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-RestMethod -ParameterFilter {
			$Uri -eq 'https://srv:4993/api/v1/users'
		}
	}

	It 'passes absolute URLs through unchanged' {
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod { [pscustomobject]@{ ok = $true } }
		Invoke-NPRequest -Path 'https://other:1/api/v1/x' | Out-Null
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-RestMethod -ParameterFilter {
			$Uri -eq 'https://other:1/api/v1/x'
		}
	}

	It 'adds count, orderBy and page for -NPE requests' {
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod {
			[pscustomobject]@{ result = [pscustomobject]@{ data = [pscustomobject]@{ items = @('x') } } }
		}
		Invoke-NPRequest -Path 'objects' -NPE | Out-Null
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-RestMethod -ParameterFilter {
			$Uri -like '*/npe/objects?count=*' -and $Uri -like '*orderBy=Name*' -and $Uri -like '*page=1*'
		}
	}

	It 'unwraps the data.items envelope' {
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod {
			[pscustomobject]@{ data = [pscustomobject]@{ items = @(1, 2, 3) } }
		}
		Invoke-NPRequest -Path 'users' | Should -Be @(1, 2, 3)
	}

	It 'unwraps data when there are no items' {
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod {
			[pscustomobject]@{ data = 'payload' }
		}
		Invoke-NPRequest -Path 'users/1' | Should -Be 'payload'
	}

	It 'serialises hashtable bodies to JSON' {
		$captured = $null
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod {
			$script:captured = $Body; [pscustomobject]@{ ok = $true }
		}
		Invoke-NPRequest -Path 'users' -Method Post -Data @{ name = 'Marc' } | Out-Null
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-RestMethod -ParameterFilter {
			$Body -match '"name"\s*:\s*"Marc"'
		}
	}

	It 'passes an already-JSON string through unchanged' {
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod { [pscustomobject]@{ ok = $true } }
		Invoke-NPRequest -Path 'users' -Method Post -Data '{"name":"Marc"}' | Out-Null
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-RestMethod -ParameterFilter {
			$Body -eq '{"name":"Marc"}'
		}
	}

	It 'writes a non-terminating error and does not throw on request failure' {
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod { throw 'boom' }
		{ Invoke-NPRequest -Path 'users' -ErrorAction SilentlyContinue } | Should -Not -Throw
	}

	It 'returns nothing (no error) when the response body is empty' {
		# Empty 2xx bodies are normal for PUT/DELETE (and POST before the Location
		# header is read). This must not raise the old "No results received" error.
		Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod { '' }
		$out = Invoke-NPRequest -Path 'filters/1' -Method Delete -ErrorAction Stop
		$out | Should -BeNullOrEmpty
	}

	# Note: surfacing the created id from the 201 Location header is verified by the
	# live integration round-trip (create -> get -> put -> delete). It cannot be
	# unit-tested here because Invoke-RestMethod's -ResponseHeadersVariable is set by
	# the real cmdlet and a mock cannot reliably populate the caller's out-variable.
}

Describe 'Connect-NPrinting' {
	BeforeEach {
		Mock -ModuleName QlikNPrinting-CLI Invoke-NPRequest { 'token' }
	}

	It 'builds the session URLs' {
		Connect-NPrinting -Computer srv -Port 4993
		InModuleScope QlikNPrinting-CLI {
			$script:NPEnv.URLServerBase | Should -Be 'https://srv:4993'
			$script:NPEnv.URLServerAPI  | Should -Be 'https://srv:4993/api/v1'
			$script:NPEnv.URLServerNPE  | Should -Be 'https://srv:4993/npe'
		}
	}

	It 'parses a full URL supplied as -Computer' {
		Connect-NPrinting -Computer 'http://host:9999'
		InModuleScope QlikNPrinting-CLI {
			$script:NPEnv.Prefix   | Should -Be 'http'
			$script:NPEnv.Computer | Should -Be 'host'
			$script:NPEnv.Port     | Should -Be '9999'
		}
	}

	It 'requires credentials for NPrinting authentication' {
		{ Connect-NPrinting -Computer srv -AuthScheme NPrinting } |
			Should -Throw '*requires -Credentials*'
	}

	It 'records the TrustAllCerts flag in the session' {
		Connect-NPrinting -Computer srv -TrustAllCerts
		InModuleScope QlikNPrinting-CLI { $script:NPEnv.TrustAllCerts | Should -BeTrue }
	}
}

Describe 'Write and action functions' {
	BeforeEach { Mock -ModuleName QlikNPrinting-CLI Invoke-NPRequest { } }

	It 'New-NPFilter POSTs to filters with the body' {
		New-NPFilter -InputObject @{ name = 'EU'; appId = 'a1' }
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Post' -and $Path -eq 'filters' -and $Data.name -eq 'EU'
		}
	}

	It 'Set-NPFilter PUTs to filters/{id}' {
		Set-NPFilter -Id 'f1' -InputObject @{ enabled = $false }
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Put' -and $Path -eq 'filters/f1'
		}
	}

	It 'Remove-NPFilter DELETEs filters/{id}' {
		Remove-NPFilter -Id 'f1' -Confirm:$false
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Delete' -and $Path -eq 'filters/f1'
		}
	}

	It 'Remove-NPFilter -WhatIf does not call the API' {
		Remove-NPFilter -Id 'f1' -WhatIf
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -Times 0
	}

	It 'Remove-NPUser accepts pipeline input by property name' {
		[pscustomobject]@{ id = 'u1' }, [pscustomobject]@{ id = 'u2' } | Remove-NPUser -Confirm:$false
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -Times 2
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter { $Path -eq 'users/u2' }
	}

	It 'New-NPUser builds the body and converts the SecureString password' {
		$pw = ConvertTo-SecureString 'S3cret!' -AsPlainText -Force
		New-NPUser -UserName jdoe -Email jdoe@x.com -Password $pw
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Post' -and $Path -eq 'users' -and
			$Data.userName -eq 'jdoe' -and $Data.email -eq 'jdoe@x.com' -and $Data.password -eq 'S3cret!'
		}
	}

	It 'Set-NPUser -Property Roles targets the roles sub-resource' {
		Set-NPUser -Id 'u1' -Property Roles -InputObject @('r1', 'r2')
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Put' -and $Path -eq 'users/u1/roles'
		}
	}

	It 'Get-NPConnections filters by appId' {
		Get-NPConnections -AppId 'a1'
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Get' -and $Path -eq 'connections?appId=a1'
		}
	}

	It 'Invoke-NPConnectionReload POSTs to the reload action' {
		Invoke-NPConnectionReload -Id 'c1' -Confirm:$false
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Post' -and $Path -eq 'connections/c1/reload'
		}
	}

	It 'Start-NPTask POSTs a new execution' {
		Start-NPTask -Id 't1' -Confirm:$false
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Post' -and $Path -eq 'tasks/t1/executions'
		}
	}

	It 'Get-NPTaskExecutions targets a single execution when given -ExecutionId' {
		Get-NPTaskExecutions -TaskId 't1' -ExecutionId 'e1'
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Get' -and $Path -eq 'tasks/t1/executions/e1'
		}
	}

	It 'New-NPOnDemandRequest builds a request body from -ReportId' {
		New-NPOnDemandRequest -ReportId 'r1' -OutputFormat 'pdf'
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Post' -and $Path -eq 'ondemand/requests' -and
			$Data.reportId -eq 'r1' -and $Data.outputFormat -eq 'pdf'
		}
	}

	It 'Get-NPAuditLogs GETs audit/logs' {
		Get-NPAuditLogs
		Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-NPRequest -ParameterFilter {
			$Method -eq 'Get' -and $Path -eq 'audit/logs'
		}
	}
}

Describe 'Regression - GitHub issues' {
	Context 'Issue #7: Connect-NPrinting -TrustAllCerts on PowerShell 7' {
		BeforeEach { Mock -ModuleName QlikNPrinting-CLI Invoke-NPRequest { 'token' } }

		It 'does not raise the null-valued-method error when connecting with credentials' {
			$cred = [pscredential]::new('tech', (ConvertTo-SecureString 'p' -AsPlainText -Force))
			{ Connect-NPrinting -Computer np.example.com -TrustAllCerts -Credentials $cred } |
				Should -Not -Throw
			InModuleScope QlikNPrinting-CLI { $script:NPEnv.TrustAllCerts | Should -BeTrue }
		}

		It 'adds -SkipCertificateCheck per request on PowerShell 7' {
			if ($PSVersionTable.PSVersion.Major -le 5) {
				Set-ItResult -Skipped -Because 'per-request cert skip is a PowerShell 7 behavior'
				return
			}
			New-TestSession
			InModuleScope QlikNPrinting-CLI { $script:NPEnv.TrustAllCerts = $true }
			Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod { [pscustomobject]@{ ok = $true } }
			Invoke-NPRequest -Path 'users' | Out-Null
			Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-RestMethod -ParameterFilter {
				$SkipCertificateCheck -eq $true
			}
		}
	}

	Context 'Issue #5: ConvertTo-Json depth' {
		BeforeEach { New-TestSession }

		It 'serialises nested bodies beyond the default depth (does not truncate)' {
			# a->b->c->d is 4 levels deep; the ConvertTo-Json default of 2 would
			# stringify the inner levels as type names instead of JSON.
			$deep = @{ a = @{ b = @{ c = @{ d = 'deepvalue' } } } }
			Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod { [pscustomobject]@{ ok = $true } }
			Invoke-NPRequest -Path 'filters/1' -Method Put -Data $deep | Out-Null
			Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-RestMethod -ParameterFilter {
				$Body -match 'deepvalue' -and $Body -notmatch 'System\.Collections'
			}
		}

		It 'honours an explicit -Depth for deeper structures' {
			$deeper = @{ l1 = @{ l2 = @{ l3 = @{ l4 = @{ l5 = @{ l6 = 'bottom' } } } } } }
			Mock -ModuleName QlikNPrinting-CLI Invoke-RestMethod { [pscustomobject]@{ ok = $true } }
			Invoke-NPRequest -Path 'filters/1' -Method Put -Data $deeper -Depth 8 | Out-Null
			Should -Invoke -ModuleName QlikNPrinting-CLI Invoke-RestMethod -ParameterFilter {
				$Body -match 'bottom'
			}
		}
	}
}

# SIG # Begin signature block
# MIIfdQYJKoZIhvcNAQcCoIIfZjCCH2ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBuvhchKhFLqtbK
# UxFuh8SDBpXFp+OTKBRWY9G/pdGAkaCCGb0wggN5MIIC/qADAgECAhAcz51nzeIZ
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
# ucmxEufxpHjNnnRVXX/Zv5KQq8pu/MQoOz6DC74n5+O5bSwvT5sgMYIFDjCCBQoC
# AQEwgYwweDELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMRAwDgYDVQQHDAdI
# b3VzdG9uMREwDwYDVQQKDAhTU0wgQ29ycDE0MDIGA1UEAwwrU1NMLmNvbSBDb2Rl
# IFNpZ25pbmcgSW50ZXJtZWRpYXRlIENBIEVDQyBSMgIQZUv1paC174CCCE9ugRr/
# AjANBglghkgBZQMEAgEFAKBqMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCg6yD9
# uATT86AX3fsmh5T+vK14PnLe3likTFiZjGP0LzAKBggqhkjOPQQDAgRnMGUCMQDj
# 4ftIp4drM4yiJ+Iw7F2f1Jo722A9Li/1jHaHFVRfOMSyt/si+ZbbpQiEXF1rrz0C
# MCN9493ObPCYJCL2dhmNS+B5gz1cZaa8XSnUV/WIIvKHQOV4tIZu0QtDJu9BNx4q
# x6GCA4QwggOABgkqhkiG9w0BCQYxggNxMIIDbQIBATBzMF4xCzAJBgNVBAYTAkJF
# MRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTQwMgYDVQQDEytHbG9iYWxTaWdu
# IE9mZmxpbmUgUjQ1IFRpbWVzdGFtcGluZyBDQSAyMDI1AhEAhHI/uDAN+6h1sztX
# zCY3gjALBglghkgBZQMEAgKgggFRMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTI2MDcwMTE0NDYyOVowKwYJKoZIhvcNAQk0MR4wHDAL
# BglghkgBZQMEAgKhDQYJKoZIhvcNAQEMBQAwPwYJKoZIhvcNAQkEMTIEMG5EEsAv
# hWnvoEMSPJPBJ0tjXoTkaHsyNwtPIU1bgIFmRYSpEtt2Z+1SDUXmGhDFojCBqAYL
# KoZIhvcNAQkQAgwxgZgwgZUwgZIwgY8EFB0kvxmra4s/HJGmWMXTVGSBI50uMHcw
# YqRgMF4xCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTQw
# MgYDVQQDEytHbG9iYWxTaWduIE9mZmxpbmUgUjQ1IFRpbWVzdGFtcGluZyBDQSAy
# MDI1AhEAhHI/uDAN+6h1sztXzCY3gjANBgkqhkiG9w0BAQwFAASCAYA+qclei8jg
# SScAWwgb5myTH0nzNMBBxQar56u33DgtYXS30wQnU1gcpeLPT7ZaNbnAgEgqFBB+
# b7dS3RZj39b5y2exRmf2a6psG/zsepkMcr/rc1xDPZOshLdjW7uL3sW/D+1Jjg6D
# PJHveP57Lp1lCDTwQedPgbjMR1gOhMOc196Rm7+ZcV8lfWAsnSMm96psjn/zkX+U
# mXbmnfzabVRq6G1fpwcLAY4Gic5GD2dwl/QMt34HK/er8bA2sxT5AaNeLbJhSjkE
# DoDRbklqX1nONLlV4eegnSx7WG+mLzbY7YcytJefp+sSd/cnZAuNoUxpLzem7vXW
# oqOeqVESL2eGI1gWWHvZtwmyXNCJtzL0crmuZPJTTROC8rEhrb5UPGsn6FFuGhea
# bil+8e9Yfnpcowjrj2gW7yDpd/Zheg/XloQHzmOEs2CSs4cBxOwgGX9ihODpW/k9
# vCTOsXmIo4SmpsVHbrMl9SFoIl3tqkIpilBdMaXumbkP6Q0SElDJcE8=
# SIG # End signature block
