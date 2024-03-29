#region Invoke-Connect-NPrinting_ps1
	<#
		.SYNOPSIS
			Creates a Authenticated Session Token
		
		.DESCRIPTION
			Connect-NPrinting creates the NPEnv Script Variable used to Authenticate Requests
			$Script:NPEnv
		
		.PARAMETER Prefix
			http/s prefix for the connection
		
		.PARAMETER Computer
			The NPrinting Server to connect to
		
		.PARAMETER Port
			The Port to connect on (Default: 4993)
		
		.PARAMETER Return
			Returns the Authenticated User ID
		
		.PARAMETER Credentials
			Provide a Credential to authenticate the connection with
		
		.PARAMETER TrustAllCerts
			Trust all Certificates
		
		.PARAMETER AuthScheme
			Authentication type to use, NTLM or buildin NPrinting
	
	#>
	function Connect-NPrinting
	{
		[CmdletBinding(DefaultParameterSetName = 'Default')]
		param
		(
			[Parameter(ParameterSetName = 'Default')]
			[ValidateSet('http', 'https')]
			[string]$Prefix = 'https',
			[Parameter(ParameterSetName = 'Default',
					   Position = 0)]
			[string]$Computer = $($env:computername),
			[Parameter(ParameterSetName = 'Default',
					   Position = 1)]
			[string]$Port = '4993',
			[switch]$Return,
			[Parameter(ParameterSetName = 'Default')]
			[Parameter(ParameterSetName = 'Creds')]
			[pscredential]$Credentials,
			[Parameter(ParameterSetName = 'Default')]
			[switch]$TrustAllCerts,
			[ValidateSet('ntlm', 'NPrinting')]
			[string]$AuthScheme = "ntlm"
		)
		
		$APIPath = "api"
		$APIVersion = "v1"
		
		if ($PSVersionTable.PSVersion.Major -gt 5 -and $TrustAllCerts.IsPresent -eq $true)
		{
			$Script:SplatRest.Add("SkipCertificateCheck", $TrustAllCerts)
		}
		else
		{
			if ($TrustAllCerts.IsPresent -eq $true)
			{
				if (-not ("CTrustAllCerts" -as [type]))
				{
					add-type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class CTrustAllCerts {
    public static bool ReturnTrue(object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }

    public static RemoteCertificateValidationCallback GetDelegate() {
        return new RemoteCertificateValidationCallback(CTrustAllCerts.ReturnTrue);
    }
}
"@
					Write-Verbose -Message "Added Cert Ignore Type"
				}
				
				[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [CTrustAllCerts]::GetDelegate()
				[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
				Write-Verbose -Message "Server Certificate Validation Bypass"
			}
		}
		
		if ($Computer -eq $($env:computername))
		{
			$NPService = Get-Service -Name 'QlikNPrintingWebEngine'
			if ($null -eq $NPService)
			{
				Write-Error -Message "Local Computer Name used and Service in not running locally"
				break
			}
		}
		
		if ($Computer -match ":")
		{
			If ($Computer.ToLower().StartsWith("http"))
			{
				$Prefix, $Computer = $Computer -split "://"
			}
			
			if ($Computer -match ":")
			{
				$Computer, $Port = $Computer -split ":"
			}
		}
		$CookieMonster = New-Object System.Net.CookieContainer
		$script:NPEnv = @{
			TrustAllCerts = $TrustAllCerts.IsPresent
			Prefix	      = $Prefix
			Computer	  = $Computer
			Port		  = $Port
			API		      = $APIPath
			APIVersion    = $APIVersion
			URLServerAPI  = ""
			URLServerNPE  = ""
			URLServerBase = ""
			WebRequestSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
		}
		if ($null -ne $Credentials)
		{
			$NPEnv.Add("Credentials", $Credentials)
		}
		$NPEnv.URLServerBase = "$($NPEnv.Prefix)://$($NPEnv.Computer):$($NPEnv.Port)"
		$NPEnv.URLServerAPI = "$($NPEnv.URLServerBase)/$($NPEnv.API)/$($NPEnv.APIVersion)"
		$NPEnv.URLServerNPE = "$($NPEnv.URLServerBase)/npe"
		
		$WRS = $NPEnv.WebRequestSession
		$WRS.UserAgent = "Windows"
		$WRS.Cookies = $CookieMonster
		
		switch ($PsCmdlet.ParameterSetName)
		{
			'Default' {
				$WRS.UseDefaultCredentials = $true
				$APIAuthScheme = "ntlm"
				break
			}
			'Creds' {
				$WRS.Credentials = $Credentials
				$APIAuthScheme = "ntlm"
				break
			}
		}
		
		if ($AuthScheme -eq "Nprinting")
		{
			$URLServerLogin = "$($NPEnv.URLServerBase)"
		}
		else
		{
			$URLServerLogin = "$($NPEnv.URLServerAPI)/login/$($APIAuthScheme)"
		}
		
		Write-Verbose -Message $URLServerLogin
		$paramInvokeNPRequest = @{
			Path   = $URLServerLogin
			method = 'get'
		}
		if ($PSBoundParameters.Debug.IsPresent)
		{
			$paramInvokeNPRequest.Debug = $true
		}
		$AuthToken = Invoke-NPRequest @paramInvokeNPRequest
		
		if ($AuthScheme -eq "NPrinting")
		{
			#With NPrinting Auth, we first have to get the X-XSRF-Token
			#then submit the credentials.
			$body = @{
				username = $Credentials.UserName
				password = $Credentials.GetNetworkCredential().Password
			} | ConvertTo-Json
			$URLServerLogin = "$($NPEnv.URLServerBase)/login"
			$paramInvokeNPRequest = @{
				Path   = $URLServerLogin
				method = 'post'
				Data   = $body
			}
			if ($PSBoundParameters.Debug.IsPresent)
			{
				$paramInvokeNPRequest.Debug = $true
			}
			$AuthToken = Invoke-NPRequest @paramInvokeNPRequest
			$body = $null
		}
			
		if ($PSBoundParameters.Debug.IsPresent) { $Global:NPEnv = $script:NPEnv }
		
		if ($Return -eq $true)
		{
			$AuthToken
		}
	}
	
	#Compatibility Alias Prior to renaming
	#Set-Alias -Name Get-NPSession -Value Connect-NPrinting
#endregion

#region Invoke-Invoke-NPRequest_ps1
	function Invoke-NPRequest
	{
		param
		(
			[Parameter(Mandatory = $true,
					   Position = 0)]
			[string]$Path,
			[ValidateSet('Get', 'Post', 'Patch', 'Delete', 'Put')]
			[string]$method = 'Get',
			$Data,
			[Parameter(ParameterSetName = 'NPE',
					   Mandatory = $false)]
			[switch]$NPE,
			[Parameter(ParameterSetName = 'NPE')]
			[int]$Count = -1,
			[Parameter(ParameterSetName = 'NPE')]
			[string]$OrderBy = 'Name',
			[Parameter(ParameterSetName = 'NPE')]
			[int]$Page = 1,
			[system.IO.FileInfo]$OutFile
		)
		
		$NPEnv = $script:NPEnv
		
		if ($null -eq $NPEnv)
		{
			Write-Warning "Attempting to establish Default connection"
			Connect-NPrinting
		}
		if ([uri]::IsWellFormedUriString($path, [System.UriKind]::Absolute))
		{
			$URI = $path
		}
		else
		{
			if ($NPE.IsPresent -eq $true)
			{
				$NPEPath = $Path
				if ($NPEPath.Contains("?"))
				{
					$join = "&"
				}
				else
				{
					$join = "?"
				}
				if (!($NPEPath.Contains("count=")))
				{
					$NPEPath = "$($NPEPath)$($join)count=$($Count)"
					$join = "&"
				}
				if (!($NPEPath.Contains("orderBy=")))
				{
					$NPEPath = "$($NPEPath)$($join)orderBy=$($OrderBy)"
					$join = "&"
				}
				if (!($NPEPath.Contains("page=")))
				{
					$NPEPath = "$($NPEPath)$($join)page=$($Page)"
					$join = "&"
				}
				$URI = "$($NPEnv.URLServerNPE)/$($NPEPath)"
			}
			else
			{
				$URI = "$($NPEnv.URLServerAPI)/$($path)"
			}
		}
		
		$Script:SplatRest = @{
			URI = $URI
			WebSession = $($NPEnv.WebRequestSession)
			Method = $method
			ContentType = "application/json;charset=UTF-8"
			Headers = Get-XSRFToken
		}
		
		if ("" -eq $NPEnv.WebRequestSession.Cookies.GetCookies($NPEnv.URLServerAPI) -and ($null -ne $NPEnv.Credentials))
		{
			$SplatRest.Add("Credential", $NPEnv.Credentials)
		}
		
		#Convert Data to Json and add to body of request
		if ($null -ne $data)
		{
			if ($Data.GetType().name -like "Array*")
			{
				$jsondata = Convertto-Json -InputObject $Data -Depth 5
			}
			elseif ($Data.GetType().name -ne "string")
			{
				$jsondata = Convertto-Json -InputObject $Data -Depth 5
			}
			else
			{
				$jsondata = $Data
			}
			
			#Catch All
			if (!(($jsondata.StartsWith('{') -and $jsondata.EndsWith('}')) -or ($jsondata.StartsWith('[') -and $jsondata.EndsWith(']'))))
			{
				$jsondata = Convertto-Json -InputObject $Data -Depth 5
			}
			
			$SplatRest.Add("Body", $jsondata)
		}
		
		if ($PSBoundParameters.Keys.Contains("OutFile"))
		{
			$SplatRest.outFile = $OutFile
		}
		
		if ($PSBoundParameters.Debug.IsPresent)
		{
			$Global:NPSplat = $SplatRest
		}
		
		try
		{
			$Result = Invoke-RestMethod @SplatRest
		}
		catch [System.Net.WebException]{
			$EXCEPTION = $_.Exception
			$EXCEPTION
			Write-Warning -Message "From: $($Exception.Response.ResponseUri.AbsoluteUri) `nResponse: $($Exception.Response.StatusDescription)"
			break
		}
		
		if ($PSBoundParameters.Debug.IsPresent)
		{
			Write-Warning "Session XSRF Token: $(Get-XSRFToken -Raw)"
		}
		
		if ($PSBoundParameters.keys.Contains("OutFile"))
		{
			Return
		}
		elseif ($Null -ne $Result)
		{
			if ($NPE.IsPresent -eq $true -or $null -ne $Result.result)
			{
				$Result = $Result.Result
			}
			if ((($Result | Get-Member -MemberType Properties).count -eq 1 -and ($null -ne $Result.data)))
			{
				if ($null -ne $Result.data.items)
				{
					$Result.data.items
				}
				else
				{
					$Result.data
				}
			}
			else
			{
				$Result
			}
		}
		else
		{
			Write-Error -Message "no Results received"
		}
	}
#endregion

#region Invoke-GetNPFilter_ps1
	Function GetNPFilter ($Property, $Value, $Filter)
	{
		if ($null -ne $Property)
		{
			$Value = $Value.replace('*', '%')
			if ($Filter.StartsWith("?")) { $qt = "&" }
			else { $qt = "?" }
			$Filter = "$($Filter)$($qt)$($Property)=$($Value)"
		}
		$Filter
	}
#endregion

#region Invoke-Add-NPProperty_ps1
	
	Function Add-NPProperty ($Property,$NPObject,$path) {
	$PropertyValues = Get-Variable -Name "NP$($Property)" -ValueOnly -ErrorAction SilentlyContinue
	$NPObject | ForEach-Object{
	        $Object = $_
	        $ObjPath = "$($path)/$($Object.ID)/$Property"
	        $NPObjProperties = $(Invoke-NPRequest -Path $ObjPath -method Get)
	        $LookupProperties = $NPObjProperties | ForEach-Object{
	            $ObjProperty = $_;
	            $ObjectProperty = $PropertyValues | Where-Object{ $_.id -eq $ObjProperty }
	            if ($Null -eq $ObjectProperty)
	            {
	                Write-Verbose "$($ObjProperty) Missing from Internal $($Property) List: Updating"
	                & "Get-NP$($Property)" -update
	                $PropertyValues = Get-Variable -Name "NP$($Property)" -ValueOnly
	                $ObjectProperty = $PropertyValues | Where-Object{ $_.id -eq $ObjProperty }
	            }
	            $ObjectProperty
	        }
	        Add-Member -InputObject $Object -MemberType NoteProperty -Name $Property -Value $LookupProperties
	    }
	}
	
#endregion

#region Invoke-Get-NPFilters_ps1
	function Get-NPFilters
	{
		param
		(
			[parameter(DontShow)]
			[switch]$Update
		)
		$Script:NPFilters = Invoke-NPRequest -Path "Filters" -method Get
		#The Update Switch is used to refresh the Internal List only
		#It is used when Called from Get-NPUsers and a Property is missing from the Internal List
		#The Internal List is used to speed up operations, by minimizing requests for data we have already received
		if ($Update.IsPresent -eq $false)
		{
			$Script:NPFilters
		}
	}
#endregion

#region Invoke-Get-NPGroups_ps1
	Function Get-NPGroups
	{
		param
		(
			[int32]$limit,
			[parameter(DontShow)]
			[switch]$Update
		)
		$filter = ""
		if ("limit" -in $PSBoundParameters.Keys){ $Filter = GetNPFilter -Filter $Filter -Property "limit" -Value $limit.ToString() } 
		
		$Script:NPGroups = Invoke-NPRequest -Path "groups$Filter" -method Get
		
		#The Update Switch is used to refresh the Internal List only
		#It is used when Called from Get-NPUsers and a Property is missing from the Internal List
		#The Internal List is used to speed up operations, by minimizing requests for data we have already received
		if ($Update.IsPresent -eq $false)
		{
			$Script:NPGroups
		}
	}
	
#endregion

#region Invoke-Get-NPRoles_ps1
	function Get-NPRoles
	{
		param
		(
			[parameter(DontShow)]
			[switch]$Update
		)
		
		$Script:NPRoles = Invoke-NPRequest -Path "roles" -method Get
		
		#The Update Switch is used to refresh the Internal List only
		#It is used when Called from Get-NPUsers and a Property is missing from the Internal List
		#The Internal List is used to speed up operations, by minimizing requests for data we have already received
		if ($Update.IsPresent -eq $false)
		{
			$Script:NPRoles
		}
	}
#endregion

#region Invoke-Get-NPTasks_ps1
	function Get-NPTasks
	{
		param
		(
			$ID,
			[string]$Name,
			[switch]$Executions,
			[parameter(DontShow)]
			[switch]$Update
		)
		$BasePath = "tasks"
		
		if ($Null -ne $ID)
		{
			$Path = "$BasePath/$($ID)"
		}
		else
		{
			$Path = "$BasePath"
		}
		
		$Path = "$($Path)$($Filter)"
		Write-Verbose $Path
		
		#The Update Switch is used to refresh the Internal List only
		#It is used when Called from Get-NPUsers and a Property is missing from the Internal List
		#The Internal List is used to speed up operations, by minimizing requests for data we have already received
		$Script:NPTasks = Invoke-NPRequest -Path $Path -method Get
		
		if ($Executions.IsPresent)
		{
			$NPTasks | ForEach-Object{
				$ExecutionPath = "tasks/$($_.id)/Executions"
				$NPTaskExecutions = Invoke-NPRequest -Path $ExecutionPath -method Get
				Add-Member -InputObject $_ -MemberType NoteProperty -Name "Executions" -Value $NPTaskExecutions
			}
		}
		
		if ($Update.IsPresent -eq $false)
		{
			$Script:NPTasks
		}
		
	}
#endregion

#region Invoke-NPUsers_ps1
	
	<#
	#Avaliable APIs
	    Get-NPUsers
	    get /users
	    get /users/{id}
	    get /users/{id}/filters
	    get /users/{id}/groups
	    get /users/{id}/roles
	
	    Update-NPUser
	    put /users/{id}/filters
	    put /users/{id}/groups
	    put /users/{id}
	    put /users/{id}/roles
	
	    New-NPUser
	    post /users
	
	    Remove-NPUser
	    delete /users/{id}
	
	#>
	
	<#
	#Implemented APIS
	Get-NPUsers
	get /users
	get /users/{id}
	get /users/{id}/filters
	get /users/{id}/groups
	get /users/{id}/roles
	#>
	
	<#
		.SYNOPSIS
			Gets details of the Users in NPrinting
		
		.DESCRIPTION
			A detailed description of the Get-NPUsers function.
		
		.PARAMETER ID
			ID of object to get.
		
		.PARAMETER UserName
			Username of object to get.
		
		.PARAMETER Email
			Email address of object to get.
		
		.PARAMETER roles
			Include Role.
		
		.PARAMETER groups
			Inlcude Groups.
		
		.PARAMETER filters
			Include Filters.
		
		.PARAMETER limit
			number of objects to return (default is 50).
	
		.EXAMPLE
			Get-NPUsers -roles -groups -filters
			Get-NPUsers -UserName Marc -roles -groups -filters
		
		.NOTES
			Additional information about the function.
	#>
	function Get-NPUsers
	{
		[CmdletBinding()]
		param
		(
			[Parameter(ValueFromPipeline = $true)]
			[string]$ID,
			[string]$UserName,
			[string]$Email,
			[switch]$roles,
			[switch]$groups,
			[switch]$filters,
			[int32]$limit
		)
		$BasePath = "Users"
		$Filter = ""
		if ("limit" -in $PSBoundParameters.Keys) { $Filter = GetNPFilter -Filter $Filter -Property "limit" -Value $limit.ToString() }
		if ("UserName" -in $PSBoundParameters.Keys) { $Filter = GetNPFilter -Filter $Filter -Property "UserName" -Value $UserName }
		if ("EMail" -in $PSBoundParameters.Keys) { $Filter = GetNPFilter -Filter $Filter -Property "EMail" -Value $EMail }
		
		if ("ID" -in $PSBoundParameters.Keys) { $Path = "$BasePath/$($ID)" }
		else { $Path = "$BasePath" }
		
		$Path = "$($Path)$($Filter)"
		$NPUsers = Invoke-NPRequest -Path $Path -method Get
		
		if ($roles.IsPresent)
		{
			AddNPProperty -Property "Roles" -NPObject $NPUsers -path $BasePath
		}
		if ($groups.IsPresent)
		{
			AddNPProperty -Property "Groups" -NPObject $NPUsers -path $BasePath
		}
		if ($filters.IsPresent)
		{
			AddNPProperty -Property "Filters" -NPObject $NPUsers -path $BasePath
		}
		$NPUsers
	}
	
#endregion

#region Invoke-NPReports_ps1
	
	#This Function is a mess, it kinda works, but there will be filter scenarios where it is broken.
	#WIP
	function Get-NPReports{
		param
		(
			$ID,
			[string]$Name,
			[parameter(DontShow)]
			[switch]$Update
		)
		$BasePath = "Reports"
		
		if ($Null -ne $ID)
		{
			$Path = "$BasePath/$($ID)"
		}
		else
		{
			$Path = "$BasePath"
		}
		
		$Path = "$($Path)$($Filter)"
	    Write-Verbose $Path
	    
	    #The Update Switch is used to refresh the Internal List only
		#It is used when Called from Get-NPUsers and a Property is missing from the Internal List
		#The Internal List is used to speed up operations, by minimizing requests for data we have already received
		$Script:NPReports = Invoke-NPRequest -Path $Path -method Get
		if ($Update.IsPresent -eq $false)
		{
			$Script:NPReports
		}
		
	}
	
#endregion

#region Invoke-NPApps_ps1
	
	#This Function is a mess, it kinda works, but there will be filter scenarios where it is broken.
	#WIP
	function Get-NPApps
	{
		param
		(
			$ID,
			[string]$Name,
			[parameter(DontShow)]
			[switch]$Update
		)
		$BasePath = "Apps"
		
		if ($Null -ne $ID)
		{
			$Path = "$BasePath/$($ID)"
		}
		else
		{
			$Path = "$BasePath"
		}
		
		$FilterApps = $Script:NPapps
		
		switch ($PSBoundParameters.Keys)
		{
			name{
				if ($Name -match '\*')
				{
					$FilterApps = $FilterApps | Where-Object { $_.name -like $Name }
				}
				else
				{
					$FilterApps = $FilterApps | Where-Object { $_.name -eq $Name }
				}
			}
			ID{ $Path = "$BasePath/$($ID)" }
			Update{ $Path = "$BasePath" }
			Default { $Path = "$BasePath" }
		}
		
		$Path = "$($Path)$($Filter)"
	    Write-Verbose $Path
	    
	    #The Update Switch is used to refresh the Internal List only
		#It is used when Called from Get-NPUsers and a Property is missing from the Internal List
		#The Internal List is used to speed up operations, by minimizing requests for data we have already received
		
		if ($Null -eq $FilterApps)
		{
			$Script:NPapps = Invoke-NPRequest -Path $Path -method Get
			if ($Update.IsPresent -eq $false)
			{
				$Script:NPapps
			}
		}
		else
		{
			if ($Update.IsPresent -eq $false)
			{
				$FilterApps
			}
			
		}
		
	}
	
#endregion

#region Invoke-GetXSRFToken_ps1
	
	function Get-XSRFToken
	{
		[CmdletBinding()]
		param
		(
			[switch]$Raw
		)
		
		$token = $script:NPenv.WebRequestSession.Cookies.GetCookies($script:NPEnv.URLServerBase) | Where-Object{ $_.name -eq "NPWEBCONSOLE_XSRF-TOKEN" }
		$Header = New-Object 'System.Collections.Generic.Dictionary[String,String]'
		$Header.Add("X-XSRF-TOKEN", $token.Value)
		if ($Raw.IsPresent)
		{
			return $token.Value
		}
		else
		{
			return $Header
		}
		
	}
	
	
#endregion

	<#	
		===========================================================================
		 Created on:   	2018-12-03
		 Updated on:   	2022-10-24
		 Created by:   	Marc Collins
		 Organization: 	Qlik - Customer Success
		 Filename:     	QlikNPrinting-CLI.psm1
		-------------------------------------------------------------------------
		 Module Name: QlikNPrinting-CLI
		===========================================================================
		Qlik NPrinting CLI - PowerShell Module to work with NPrinting
		The Function "Invoke-NPRequest" can be used to access all the NPrinting API's
	#>
	
# SIG # Begin signature block
# MIIm7AYJKoZIhvcNAQcCoIIm3TCCJtkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCAdM4cgkTsR/lP
# y9d01cPl9xfb3fHQbMZSHWvySdM0q6CCH5MwggWDMIIDa6ADAgECAg5F5rsDgzPD
# hWVI5v9FUTANBgkqhkiG9w0BAQwFADBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJv
# b3QgQ0EgLSBSNjETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFs
# U2lnbjAeFw0xNDEyMTAwMDAwMDBaFw0zNDEyMTAwMDAwMDBaMEwxIDAeBgNVBAsT
# F0dsb2JhbFNpZ24gUm9vdCBDQSAtIFI2MRMwEQYDVQQKEwpHbG9iYWxTaWduMRMw
# EQYDVQQDEwpHbG9iYWxTaWduMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKC
# AgEAlQfoc8pm+ewUyns89w0I8bRFCyyCtEjG61s8roO4QZIzFKRvf+kqzMawiGvF
# tonRxrL/FM5RFCHsSt0bWsbWh+5NOhUG7WRmC5KAykTec5RO86eJf094YwjIElBt
# QmYvTbl5KE1SGooagLcZgQ5+xIq8ZEwhHENo1z08isWyZtWQmrcxBsW+4m0yBqYe
# +bnrqqO4v76CY1DQ8BiJ3+QPefXqoh8q0nAue+e8k7ttU+JIfIwQBzj/ZrJ3YX7g
# 6ow8qrSk9vOVShIHbf2MsonP0KBhd8hYdLDUIzr3XTrKotudCd5dRC2Q8YHNV5L6
# frxQBGM032uTGL5rNrI55KwkNrfw77YcE1eTtt6y+OKFt3OiuDWqRfLgnTahb1SK
# 8XJWbi6IxVFCRBWU7qPFOJabTk5aC0fzBjZJdzC8cTflpuwhCHX85mEWP3fV2ZGX
# hAps1AJNdMAU7f05+4PyXhShBLAL6f7uj+FuC7IIs2FmCWqxBjplllnA8DX9ydoo
# jRoRh3CBCqiadR2eOoYFAJ7bgNYl+dwFnidZTHY5W+r5paHYgw/R/98wEfmFzzNI
# 9cptZBQselhP00sIScWVZBpjDnk99bOMylitnEJFeW4OhxlcVLFltr+Mm9wT6Q1v
# uC7cZ27JixG1hBSKABlwg3mRl5HUGie/Nx4yB9gUYzwoTK8CAwEAAaNjMGEwDgYD
# VR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFK5sBaOTE+Ki
# 5+LXHNbH8H/IZ1OgMB8GA1UdIwQYMBaAFK5sBaOTE+Ki5+LXHNbH8H/IZ1OgMA0G
# CSqGSIb3DQEBDAUAA4ICAQCDJe3o0f2VUs2ewASgkWnmXNCE3tytok/oR3jWZZip
# W6g8h3wCitFutxZz5l/AVJjVdL7BzeIRka0jGD3d4XJElrSVXsB7jpl4FkMTVlez
# orM7tXfcQHKso+ubNT6xCCGh58RDN3kyvrXnnCxMvEMpmY4w06wh4OMd+tgHM3ZU
# ACIquU0gLnBo2uVT/INc053y/0QMRGby0uO9RgAabQK6JV2NoTFR3VRGHE3bmZbv
# GhwEXKYV73jgef5d2z6qTFX9mhWpb+Gm+99wMOnD7kJG7cKTBYn6fWN7P9BxgXwA
# 6JiuDng0wyX7rwqfIGvdOxOPEoziQRpIenOgd2nHtlx/gsge/lgbKCuobK1ebcAF
# 0nu364D+JTf+AptorEJdw+71zNzwUHXSNmmc5nsE324GabbeCglIWYfrexRgemSq
# aUPvkcdM7BjdbO9TLYyZ4V7ycj7PVMi9Z+ykD0xF/9O5MCMHTI8Qv4aW2ZlatJlX
# HKTMuxWJU7osBQ/kxJ4ZsRg01Uyduu33H68klQR4qAO77oHl2l98i0qhkHQlp7M+
# S8gsVr3HyO844lyS8Hn3nIS6dC1hASB+ftHyTwdZX4stQ1LrRgyU4fVmR3l31VRb
# H60kN8tFWk6gREjI2LCZxRWECfbWSUnAZbjmGnFuoKjxguhFPmzWAtcKZ4MFWsmk
# EDCCBlkwggRBoAMCAQICDQHsHJJA3v0uQF18R3QwDQYJKoZIhvcNAQEMBQAwTDEg
# MB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjYxEzARBgNVBAoTCkdsb2Jh
# bFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMTgwNjIwMDAwMDAwWhcNMzQx
# MjEwMDAwMDAwWjBbMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBu
# di1zYTExMC8GA1UEAxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBTSEEz
# ODQgLSBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAPAC4jAj+uAb
# 4Zp0s691g1+pR1LHYTpjfDkjeW10/DHkdBIZlvrOJ2JbrgeKJ+5Xo8Q17bM0x6zD
# DOuAZm3RKErBLLu5cPJyroz3mVpddq6/RKh8QSSOj7rFT/82QaunLf14TkOI/pMZ
# F9nuMc+8ijtuasSI8O6X9tzzGKBLmRwOh6cm4YjJoOWZ4p70nEw/XVvstu/SZc9F
# C1Q9sVRTB4uZbrhUmYqoMZI78np9/A5Y34Fq4bBsHmWCKtQhx5T+QpY78Quxf39G
# mA6HPXpl69FWqS69+1g9tYX6U5lNW3TtckuiDYI3GQzQq+pawe8P1Zm5P/RPNfGc
# D9M3E1LZJTTtlu/4Z+oIvo9Jev+QsdT3KRXX+Q1d1odDHnTEcCi0gHu9Kpu7hOEO
# rG8NubX2bVb+ih0JPiQOZybH/LINoJSwspTMe+Zn/qZYstTYQRLBVf1ukcW7sUwI
# S57UQgZvGxjVNupkrs799QXm4mbQDgUhrLERBiMZ5PsFNETqCK6dSWcRi4LlrVqG
# p2b9MwMB3pkl+XFu6ZxdAkxgPM8CjwH9cu6S8acS3kISTeypJuV3AqwOVwwJ0WGe
# Joj8yLJN22TwRZ+6wT9Uo9h2ApVsao3KIlz2DATjKfpLsBzTN3SE2R1mqzRzjx59
# fF6W1j0ZsJfqjFCRba9Xhn4QNx1rGhTfAgMBAAGjggEpMIIBJTAOBgNVHQ8BAf8E
# BAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU6hbGaefjy1dFOTOk
# 8EC+0MO9ZZYwHwYDVR0jBBgwFoAUrmwFo5MT4qLn4tcc1sfwf8hnU6AwPgYIKwYB
# BQUHAQEEMjAwMC4GCCsGAQUFBzABhiJodHRwOi8vb2NzcDIuZ2xvYmFsc2lnbi5j
# b20vcm9vdHI2MDYGA1UdHwQvMC0wK6ApoCeGJWh0dHA6Ly9jcmwuZ2xvYmFsc2ln
# bi5jb20vcm9vdC1yNi5jcmwwRwYDVR0gBEAwPjA8BgRVHSAAMDQwMgYIKwYBBQUH
# AgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3JlcG9zaXRvcnkvMA0GCSqG
# SIb3DQEBDAUAA4ICAQB/4ojZV2crQl+BpwkLusS7KBhW1ky/2xsHcMb7CwmtADpg
# Mx85xhZrGUBJJQge5Jv31qQNjx6W8oaiF95Bv0/hvKvN7sAjjMaF/ksVJPkYROwf
# wqSs0LLP7MJWZR29f/begsi3n2HTtUZImJcCZ3oWlUrbYsbQswLMNEhFVd3s6Uqf
# XhTtchBxdnDSD5bz6jdXlJEYr9yNmTgZWMKpoX6ibhUm6rT5fyrn50hkaS/SmqFy
# 9vckS3RafXKGNbMCVx+LnPy7rEze+t5TTIP9ErG2SVVPdZ2sb0rILmq5yojDEjBO
# sghzn16h1pnO6X1LlizMFmsYzeRZN4YJLOJF1rLNboJ1pdqNHrdbL4guPX3x8pEw
# BZzOe3ygxayvUQbwEccdMMVRVmDofJU9IuPVCiRTJ5eA+kiJJyx54jzlmx7jqoSC
# iT7ASvUh/mIQ7R0w/PbM6kgnfIt1Qn9ry/Ola5UfBFg0ContglDk0Xuoyea+SKor
# VdmNtyUgDhtRoNRjqoPqbHJhSsn6Q8TGV8Wdtjywi7C5HDHvve8U2BRAbCAdwi3o
# C8aNbYy2ce1SIf4+9p+fORqurNIveiCx9KyqHeItFJ36lmodxjzK89kcv1NNpEdZ
# fJXEQ0H5JeIsEH6B+Q2Up33ytQn12GByQFCVINRDRL76oJXnIFm2eMakaqoimzCC
# BmgwggRQoAMCAQICEAFIkD3CirynoRlNDBxXuCkwDQYJKoZIhvcNAQELBQAwWzEL
# MAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAvBgNVBAMT
# KEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQwHhcNMjIw
# NDA2MDc0MTU4WhcNMzMwNTA4MDc0MTU4WjBjMQswCQYDVQQGEwJCRTEZMBcGA1UE
# CgwQR2xvYmFsU2lnbiBudi1zYTE5MDcGA1UEAwwwR2xvYmFsc2lnbiBUU0EgZm9y
# IE1TIEF1dGhlbnRpY29kZSBBZHZhbmNlZCAtIEc0MIIBojANBgkqhkiG9w0BAQEF
# AAOCAY8AMIIBigKCAYEAwsncA7YbUPoqDeicpCHbKKcd9YC1EnQj/l4vwxpdlrIg
# GRlQX3YjJjXGIeyU77WiOsWQgZsh7wsnpOMXZDvak9RWLzzXWPltrMAvkHgjScD4
# wY9wE9Rr3yaIWnZ7SPfhpKbvCxrzJVQPgJ4jEhIT0bD3AuMrDf9APgBCQ94a70z0
# h6nynjzQBufiY9LrTFvdXViU0+WlOSiqB152IzD8/H+YDcVlbRvVdEU6RrCiFnXe
# osIqcHy2drzZG666XZz2h5XOqqjitaOxk25ApZsQiHYWTjSh/J7x4RpU0cgkV5R2
# rcLH7KOjlnXixihrAgXoS7m14FIreAGMKjEsTOgF5W+fD4QmLmhs+stNGXwYwf9q
# GqnLvqN1+OnIGLLM3S9BQCAcz4gLF8mwikPL4muTUfERvkK8+FHy2gACvggYKAUn
# xNw7XXcpHhnUQSpmfbRSc1xCpZDTjcWjqjfOcwGUJBlCQ9GUj0t+3cttvBtOe/mq
# CyJLSYBJcBstT940YD69AgMBAAGjggGeMIIBmjAOBgNVHQ8BAf8EBAMCB4AwFgYD
# VR0lAQH/BAwwCgYIKwYBBQUHAwgwHQYDVR0OBBYEFFtre/RwdAjBDSrI7/HEuUDS
# Ssb9MEwGA1UdIARFMEMwQQYJKwYBBAGgMgEeMDQwMgYIKwYBBQUHAgEWJmh0dHBz
# Oi8vd3d3Lmdsb2JhbHNpZ24uY29tL3JlcG9zaXRvcnkvMAwGA1UdEwEB/wQCMAAw
# gZAGCCsGAQUFBwEBBIGDMIGAMDkGCCsGAQUFBzABhi1odHRwOi8vb2NzcC5nbG9i
# YWxzaWduLmNvbS9jYS9nc3RzYWNhc2hhMzg0ZzQwQwYIKwYBBQUHMAKGN2h0dHA6
# Ly9zZWN1cmUuZ2xvYmFsc2lnbi5jb20vY2FjZXJ0L2dzdHNhY2FzaGEzODRnNC5j
# cnQwHwYDVR0jBBgwFoAU6hbGaefjy1dFOTOk8EC+0MO9ZZYwQQYDVR0fBDowODA2
# oDSgMoYwaHR0cDovL2NybC5nbG9iYWxzaWduLmNvbS9jYS9nc3RzYWNhc2hhMzg0
# ZzQuY3JsMA0GCSqGSIb3DQEBCwUAA4ICAQAuaz6Pf7CwYNnxnYTclbbfXw2/JFHj
# GgaqVQTLYcHvZXGuC/2UJFcAx+T2DLwYlX0vGWpgM6a+0AhVVgS24/4eu+UQdlQ7
# q1whXio1TUbLpky6BEBgYCzb0/ad3soyEAx4sLtWxQdLcLynD6tyvI3L6+7BTGvZ
# +pihdD7pqMh5fHZ3SP3P4/ANwenDkuAHDBMvP2t/NdnVt+5vfFjA8T8MGbICo0lM
# nATD8LSXp+BNaiW6NBZiZsh4vGlzql9yojVYHibrvzIUqhJ66/SWa39yrOqnOQgz
# ATY+YSR+EZ0RHnYiVONAuy6GDHaeadLEHD2iC4yIBANU3ukbF/4sK57Z1lsiOPxk
# QIbNF3/hqZ+5v5JBqG8mavQPKLBAkZAvTrZ2ULxNI9l/T2uTKads59AwPqmTH8JQ
# KznFsvhNJyTR/XbYvvmT9KlUCtV2WNE8nuoa6CTE+zbxL1nTksPsy2BSHhxGJQj/
# ftmTrhSVqIaKBy5Ui3NMNxU4UFaH8U+uHI/JoWwvC/y7HG8tvaq262gj8O2UJxRj
# y6z0Z4osgdMUEhgBP4R6ruxHYD9oWJnJSsKhmRUFwq3eou/Xp1V8vIQbTZS7jkqF
# RNmBPaqjJVVfpGvNNmwA+f9y3lrs/8mgQZYaQGqFkRyvdWOoy1oztZQzfrKND3O+
# h/yvOnMfeyDbcjCCBnIwggRaoAMCAQICCGQzUdPHOJ8IMA0GCSqGSIb3DQEBCwUA
# MHwxCzAJBgNVBAYTAlVTMQ4wDAYDVQQIDAVUZXhhczEQMA4GA1UEBwwHSG91c3Rv
# bjEYMBYGA1UECgwPU1NMIENvcnBvcmF0aW9uMTEwLwYDVQQDDChTU0wuY29tIFJv
# b3QgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgUlNBMB4XDTE2MDYyNDIwNDQzMFoX
# DTMxMDYyNDIwNDQzMFoweDELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMRAw
# DgYDVQQHDAdIb3VzdG9uMREwDwYDVQQKDAhTU0wgQ29ycDE0MDIGA1UEAwwrU1NM
# LmNvbSBDb2RlIFNpZ25pbmcgSW50ZXJtZWRpYXRlIENBIFJTQSBSMTCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ+DE3OqsMZtIcvbi3qHdNBx3I6Xcprk
# u4g0tN2AA8YvRaR0mr8eD1Dqnm1485/6USapPZ3RspRXPvs5iRuRK1bvZ8vmC+MO
# OYzGNfSMPd0l6QGsF0J9WBZA3PnVKEQdlWQwYTpk8pfXc0x9eyMCbfN161U9b6ot
# xK++dKxd/mq2/OpceekPQ5y1UgUP7z6xsY/QSa2m40IZVD/zLw6hy3z+E/kjOdol
# HLg+AEo6bzIwN2Qex651B9hV0hjJDoq8o1zwfAqnhYHCDq+PmVzTYCW8g1ppHCUT
# zXL165yAm9wsZ8TdyQmY1XPrxCGj5TKOPi9SmMZgN2SMsm9KVHIYzCeH+s11omMh
# TLU9ZP0rpptVryZMYLS5XP6rQ72t0BNmUB8L0omm/9eABvHDEQIzM2EX91Yfji87
# aOcV8XdWSimeA9rCKyZhMlugVuVJKY02p/XHUqJWAyAvOHiAvfYGrkE0y5RFvZvH
# iRgfC7r/qa5qQJkT3e9Q3wG68gTW0DHfNDheV1vIOB5W1KxIpu3/+bjBO+3CJL5E
# YKd3zdU9mFm0Q+qqYH3NwuUv8ev11CDVlzRuXQRrBRHS05KMCSdE7U81MUZ+dBkF
# YuyJ4+ojcJjk0S/UihMYRpNl5Vhz00w9J3oiP8P4o1W3+eaHguxFHsVuOnyxTrmr
# aPebY9WRQbypAgMBAAGjgfswgfgwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAW
# gBTdBAkHovV6fVJTEpKV7jiAJQ2mWTAwBggrBgEFBQcBAQQkMCIwIAYIKwYBBQUH
# MAGGFGh0dHA6Ly9vY3Nwcy5zc2wuY29tMBEGA1UdIAQKMAgwBgYEVR0gADATBgNV
# HSUEDDAKBggrBgEFBQcDAzA7BgNVHR8ENDAyMDCgLqAshipodHRwOi8vY3Jscy5z
# c2wuY29tL3NzbC5jb20tcnNhLVJvb3RDQS5jcmwwHQYDVR0OBBYEFFTC/hCVAJPN
# avXnwNfZsku4jwzjMA4GA1UdDwEB/wQEAwIBhjANBgkqhkiG9w0BAQsFAAOCAgEA
# 9Q8mh3CvmaLK9dbJ8I1mPTmC04gj2IK/j1SEJ7bTgwfXnieJTYSOVNEg7mBD21dC
# PMewlfa+zOqjPY5PBsYrWYZ/63MbyuVAJuA9b8z2vXHGzX0OIEA51gXSr5QIv3/C
# UbcrtXuDIfBj2uWc4WkudR1Oy2Ee9aUz3wKdFdntaZNXukZFLoC8Zb7nEj7eR/+Q
# nBCt9laypNT61vwuvJchs3aD0pH6BlDRsYAogP7brQ9n7fh93NlwW3q6aLWzSmYX
# j+fw51fdaf68XuHVjJ8Tu5WaFft5K4XVbT5nR24bB1z7VEUPFhEuEcOwvLVuHDNX
# lB7+QjRGjjFQTtszV5X6OOTmEturWC5Ft9kiyvRaR0ksKOhPjEI8ZGjp5kOsGZGp
# xxOCX/xxCje3nVB7PF33olKCNeS159MKb2v+jfmk19UdS+d9Ygj42desmUnbtYRB
# FC72LmCXU0ua/vGIenS6nnXp4NqnycwsO3tMCnjPlPc2YLaDPIpUy04NaCqUEXUm
# FOogN8zreRd2VXhxbeJJODM32+RsWccjYua8zi5US/1eAyrI3R5LcUTQdT4xYmWL
# KabtJOF6HYQ0f6QXfLSsfT81WMvDvxrdn1RWbUXlU/OIiisxo8o+UNEANOwnCMNn
# xlzoaL/PLhZluDxm/zuylauajZ3MlPDteFB/7GRHo50wggbJMIIEsaADAgECAhB7
# SCAKSm9V2OChnMw3UdmtMA0GCSqGSIb3DQEBCwUAMHgxCzAJBgNVBAYTAlVTMQ4w
# DAYDVQQIDAVUZXhhczEQMA4GA1UEBwwHSG91c3RvbjERMA8GA1UECgwIU1NMIENv
# cnAxNDAyBgNVBAMMK1NTTC5jb20gQ29kZSBTaWduaW5nIEludGVybWVkaWF0ZSBD
# QSBSU0EgUjEwHhcNMjIwNjIyMDYwMjA1WhcNMjUwNjIxMDYwMjA1WjBSMQswCQYD
# VQQGEwJBVTERMA8GA1UECAwIVmljdG9yaWExEjAQBgNVBAcMCU1lbGJvdXJuZTEN
# MAsGA1UECgwETk5ldDENMAsGA1UEAwwETk5ldDCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAJ3/8woy0Ndf0Dip4ZpKULahuOqKP2vmMi2xa69VK3eg/5qY
# oGoWaFtuiyfbwRO6UqXPIY5QzcfIlEFYi20nFzax73/xT/3/fnmQwMW+5EJuNb8q
# 3DFD/ptaHd2fpd/PjzdN8PP1YRO6TkIWldR5tK5B5EJE4D6l/Yv+QdBvtWMiUrnp
# eT3k52Ei0PfHpLfkrH51N5MrBsqdqgys9WUD76dRlgP7jh9X8GPiY8AmYqbXrHFz
# anL3H9nVoNWMQXwqQNF9gfiFouwJD1C+fQVGRTahJGYveZbQbcqpUd8w3v+qMnAk
# S5BwiLZHSghvhx2jQScmPTO/vqIEevHWoFAFKL1YQuE/cBWIXqi7cUkJ9U8xDPLx
# cQ2z1VsId//yNByJ+Wo68Czloq4A37kxtVUijnlv4BH/m9NExX2XSA1c1/gUo8uZ
# jmRzWyrGUJtRwwtboDhmJt9jWuYG7pE4kYd42rKEn+KpH6zyJdl6B1zAzdzHAnhV
# PaGnjU8yEdieiCCBg9Xd8WihDFTy20pmJ53w6YpArGKOdocghUwJ7/u9LkFNnOiy
# k3q2QktUsqfJrR1T66Z8N9sSSXKQBYW1e1GBKMMRKcA7iBMad+mbCORId2lm9PPt
# 0fl48oV9wZZHdFC5h/uheoIajbc0dZgobidDBDaC84WWZpDvIgGTDtR7IPRhAgMB
# AAGjggFzMIIBbzAMBgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFFTC/hCVAJPNavXn
# wNfZsku4jwzjMFgGCCsGAQUFBwEBBEwwSjBIBggrBgEFBQcwAoY8aHR0cDovL2Nl
# cnQuc3NsLmNvbS9TU0xjb20tU3ViQ0EtQ29kZVNpZ25pbmctUlNBLTQwOTYtUjEu
# Y2VyMFEGA1UdIARKMEgwCAYGZ4EMAQQBMDwGDCsGAQQBgqkwAQMDATAsMCoGCCsG
# AQUFBwIBFh5odHRwczovL3d3dy5zc2wuY29tL3JlcG9zaXRvcnkwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwTQYDVR0fBEYwRDBCoECgPoY8aHR0cDovL2NybHMuc3NsLmNv
# bS9TU0xjb20tU3ViQ0EtQ29kZVNpZ25pbmctUlNBLTQwOTYtUjEuY3JsMB0GA1Ud
# DgQWBBQwWYeaoZ0Hpw/FGeu4mzFGYPK4QzAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZI
# hvcNAQELBQADggIBAJqkda7AGoU8YnsI9GQEF8PV69/niK0HLvoPaEr2oeDxKpHP
# XeIAP+6257sn2hYaQNeM3PigYHGHdFDPQGnTg43VlPIIEpDjf9Og1dGvb0v1eE9/
# 9y3ffr/pZ0x8yIx7b5orPBuX1/C0XdxFKPUDrdHrgVxr6GDkMjpefYz8n7quyfZo
# Egn7gEMned+ZheH0ta445ugnU3WZ29EPJzJNcIzbIhiwH6EGTOAGRM9anxmM2B1f
# 32PACepOXeTdEdmcBj0S4veU04QPd5aC6k0y8XyO81Dd57ty+MBRw/GxaoBLDegX
# 9rpsGB8jA8OhmRgxsCl4asPNrYJk8gWnUjO5yG3jbvvH2TA6MA76lt9VToCPeMt9
# Z4/+Wi0MjiQ1qmBMDP1L50lIz4fk+l7SKqDi2FWoloIlgFT5WQtsniJM6hAd4gvd
# ejp2j4CDuRhxvIZaiJP1oO8qZ5shMC1yjMHZ5h0+LaNu1a2k+JmR7Y30iEYPlX5W
# OtUqy02W45vR2UtFsxd1YIMI5ObvBd+2G6OegoYdEIgB6a4WAfQ48qyJzgFqyeVe
# Qz4eipEz19o0uz/4PHxmDajb8Byto1qBsHviYr60+fjV58SSWBplkNSTxqkpJcc+
# O0loijyeMjwnSo7xzQM4GgxeGKvKJTtD5O9kVyZGsqvWFQ64jO/Qu0d0ZlbIMYIG
# rzCCBqsCAQEwgYwweDELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMRAwDgYD
# VQQHDAdIb3VzdG9uMREwDwYDVQQKDAhTU0wgQ29ycDE0MDIGA1UEAwwrU1NMLmNv
# bSBDb2RlIFNpZ25pbmcgSW50ZXJtZWRpYXRlIENBIFJTQSBSMQIQe0ggCkpvVdjg
# oZzMN1HZrTANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgACh
# AoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAM
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDqtD9abzkmIW0+Uhi1Nxw5mQA4
# V9TrHDbKTIOLuk+qEzANBgkqhkiG9w0BAQEFAASCAgA5YPbgAUioMa0yo8ZwPsrM
# dUH4klG3qUNI/Qv/XKtupc4G+AxUITTzt1whU3JUtrHb+SlvthUsBymTateQpTNm
# wIxcYwXRTawAur/Ci1dwh+3R+JtR7AdeSe+7WwDuKUJbYEODwgqZBhOJUg7UDPZ3
# xL7Sp/5iVoLvMtKpcuXwAV/S+TCN8BMw3kVCUtiIdaQpXNsbo1VxPPyOoqgUowBS
# A9zQ2/jmu7D4ooRbtS5D2737OJuWlHJcNZU562e2dwK8i2ujiA9fi4N+s6QdZ67t
# jIrneUWw0AyhflZ/+r5alNHESrUJhWDgjv+9b/hNElJk7taWob/vqvfSGiqNukUJ
# GWPNA/VtedbVppqf/RBV9SgaokTziZcKKJGRelZMuG42ct8LwcA70uoN9iFzi5Bv
# 6OQQVENSniX8BuRk5VuA16kPESosDP3jp+fjxln5j4VrYG1cm9nXx8EjfZvkr7Qz
# fbk/mNz9KL4dyIep0IzJ2ebBTNiGUi40ULjJd7sL06IXnok7hCFmK4X8csdB9LFx
# bb5ZcX9bE2kKu1H9ANrPDn71UQh1VZfycHanCs/hdrCZU9WCM9QayhJUw1jimTTl
# 5DcaoeP1ZYVB+6j25lC9HQBeYmGOjcrXK3Nl/8XDMshJxZmsW6Lw6dLs1H2/mWpA
# rdPGemgvCN0F2yYlHmeN06GCA2wwggNoBgkqhkiG9w0BCQYxggNZMIIDVQIBATBv
# MFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYD
# VQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0AhAB
# SJA9woq8p6EZTQwcV7gpMAsGCWCGSAFlAwQCAaCCAT0wGAYJKoZIhvcNAQkDMQsG
# CSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjIxMDIzMjMzMjAxWjArBgkqhkiG
# 9w0BCTQxHjAcMAsGCWCGSAFlAwQCAaENBgkqhkiG9w0BAQsFADAvBgkqhkiG9w0B
# CQQxIgQgkgLisiDsXU+B2pDmHEyiZN1ymyX+vDaZiTKaBkk+4zcwgaQGCyqGSIb3
# DQEJEAIMMYGUMIGRMIGOMIGLBBQxAw4XaqRZLqssi63oMpn8tVhdzzBzMF+kXTBb
# MQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTExMC8GA1UE
# AxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBTSEEzODQgLSBHNAIQAUiQ
# PcKKvKehGU0MHFe4KTANBgkqhkiG9w0BAQsFAASCAYBR3grUg2kMz8UtEzMqG+OU
# penUQwtYA94Bu/kX1L72Xzf/+Xi4f7vGNfdke07mFJA5B+P+A4vEhXp5zQSO+tCc
# 3dGlkt8NHWd+iCqQCG30J4wqEwlwgnj2pQdAdwZI67LuVoufjUHYFR/VkstnoCaF
# U3JsOWocTD9xPo0LCAQFlMMJHVY2LHE5BUvkY1Z5CGypy+jK3PcwTLUOxspitIYw
# DacztiqP5kx4KryospJck2OYeQ7ZS46/ddXA/YqBeBq/exd6p3H9/flaatD/Hn+H
# iTqB3FnH2wveTyf/Ko1sR2Hxj3E5+/zn/e1MBntpednPBVRImtZuLMF3GmpLg48Z
# KsKkW8Oc3i7Glf2PYCgzA1m2Z8bNyTK0reQMA7Rhoz9u1BcSI4JlUaZNpBz050Ve
# 2Wm9wg1khEjcKR3lGpAuZkj548ra5V6EgpeUdX965R6A05eFRetKzx6UwQwzM2ud
# ptRt/wGUaCjr/Fc5LciB2RZmsbBQdPu6IkbqptxzkaE=
# SIG # End signature block
