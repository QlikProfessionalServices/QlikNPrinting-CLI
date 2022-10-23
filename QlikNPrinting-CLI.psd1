<#	
	===========================================================================
	 Created on:   	2018-12-03
	 Updated on:   	2022-10-24
	 Created by:   	Marc Collins
	 Organization: 	Qlik - Customer Success
	 Filename:     	QlikNPrinting-CLI.psd1
	 -------------------------------------------------------------------------
	 Module Manifest
	-------------------------------------------------------------------------
	 Module Name: QlikNPrinting-CLI
	===========================================================================
#>

@{
	
	# Script module or binary module file associated with this manifest
	RootModule = 'QlikNPrinting-CLI.psm1'
	
	# Version number of this module.
	ModuleVersion = '1.0.0.10'
	
	# ID used to uniquely identify this module
	GUID = 'eca92804-c4ca-4aa8-9313-44d71005379d'
	
	# Author of this module
	Author = 'Marc Collins'
	
	# Company or vendor of this module
	CompanyName = 'Qlik - Customer Success'
	
	# Copyright statement for this module
	Copyright = '(c) 2022. All rights reserved.'
	
	# Description of the functionality provided by this module
	Description = 'PowerShell module to interact with the NPrinting APIs'
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '4.0'
	
	# Name of the Windows PowerShell host required by this module
	PowerShellHostName = ''
	
	# Minimum version of the Windows PowerShell host required by this module
	PowerShellHostVersion = ''
	
	# Minimum version of the .NET Framework required by this module
	DotNetFrameworkVersion = '2.0'
	
	# Minimum version of the common language runtime (CLR) required by this module
	CLRVersion = '2.0.50727'
	
	# Processor architecture (None, X86, Amd64, IA64) required by this module
	ProcessorArchitecture = 'None'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules = @()
	
	# Assemblies that must be loaded prior to importing this module
	RequiredAssemblies = @()
	
	# Script files (.ps1) that are run in the caller's environment prior to
	# importing this module
	ScriptsToProcess = @()
	
	# Type files (.ps1xml) to be loaded when importing this module
	TypesToProcess = @()
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess = @()
	
	# Modules to import as nested modules of the module specified in
	# ModuleToProcess
	NestedModules = @()
	
	# Functions to export from this module
	FunctionsToExport = @(
		'Connect-NPrinting',
		'Invoke-NPRequest',
		'Get-NPFilters',
		'Get-NPGroups',
		'Get-NPRoles',
		'Get-NPTasks',
		'Get-NPUsers',
		'Get-NPReports',
		'Get-NPApps'
	) #For performance, list functions explicitly
	
	# Cmdlets to export from this module
	CmdletsToExport = '*' 
	
	# Variables to export from this module
	VariablesToExport = '*'
	
	# Aliases to export from this module
	AliasesToExport = '' #For performance, list alias explicitly
	
	# DSC class resources to export from this module.
	#DSCResourcesToExport = ''
	
	# List of all modules packaged with this module
	ModuleList = @()
	
	# List of all files packaged with this module
	FileList = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags = @('Qlik', 'NPrinting', 'NPrintingAPI','API')
			
			# A URL to the license for this module.
			LicenseUri = 'https://raw.githubusercontent.com/QlikProfessionalServices/QlikNPrinting-CLI/master/LICENSE'
			
			# A URL to the main website for this project.
			ProjectUri = 'https://github.com/QlikProfessionalServices/QlikNPrinting-CLI'
			
			# A URL to an icon representing this module.
			# IconUri = ''
			
			# ReleaseNotes of this module
			ReleaseNotes = 'https://raw.githubusercontent.com/QlikProfessionalServices/QlikNPrinting-CLI/master/README.md'
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}

# SIG # Begin signature block
# MIIm7AYJKoZIhvcNAQcCoIIm3TCCJtkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDOXY6fPnySRXPC
# bL2M490lrv2gjQo8Tig5M74gsdsYOKCCH5MwggWDMIIDa6ADAgECAg5F5rsDgzPD
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCbLTw+/SmdZWb3Eaf75XdmB6Xy
# KzCgBY4UCwXLyiS5HzANBgkqhkiG9w0BAQEFAASCAgAFV+inajbQtF01yRV7HvDC
# x+S0xJXHO6jAva4G34YLJw8ltl2Lv72dWoyFK64LomEb9wQiFBA+4IOPH6MrYCMK
# Zm6W1uaKN+FNulKYiZa7c94+EAOdfTCvBGiRCm/3W2MfdTfyoF9TJcwEm/unevhc
# 7N/+vMcMeFpe4oxCqAyPxmfMqsQxZzkJMYLhCiyhFJAl8yvjv9Sr/SiVP42OCxNF
# XvWsX0FVSIV++MV6bn63A23odX+oiNFkz6p9ZK7GSxWq3WDeqnofHQascnBGKcKA
# rIMy3MGpCIljWhY3RnnzYcRlf7WtBsu2r9+SJigNDJBVgpcBhoeHkXAfjC8wPO3t
# ggHbtUMzjY/iMs7p5ZrIzNqZgjrvQWAGhMhSolPty456G8Q13Z1tPud9x/aFIfzk
# O14fslQF06jI/upFt0MrEPptvojwIGU6oAB/lzuo+yKPiPG3xF4DLo7piOI6rJ0w
# S3+7ckcBuAODn2A0NzkZMbw8i7VpJc4x70YbEclmeVCGKUJH5f1+s1euY/6w86xO
# nj3YIm6Jr/fZYINyZgOXPTHJMI987eux91tBms2NpTDHSEj8fCz/tzKPIFpcUpnI
# Q7cHyRJfjD/Gbl6rYk1g1cjsg9ihP6m+nEIlNnI5DdloYlNunP6VOUlZzporDEId
# PL31bqTZ3o8JxaACFLYUiqGCA2wwggNoBgkqhkiG9w0BCQYxggNZMIIDVQIBATBv
# MFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYD
# VQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0AhAB
# SJA9woq8p6EZTQwcV7gpMAsGCWCGSAFlAwQCAaCCAT0wGAYJKoZIhvcNAQkDMQsG
# CSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjIxMDIzMjMzMjAxWjArBgkqhkiG
# 9w0BCTQxHjAcMAsGCWCGSAFlAwQCAaENBgkqhkiG9w0BAQsFADAvBgkqhkiG9w0B
# CQQxIgQg3hHaqzdmIzTKouZzsXFwyWH3O1GogriIpwytPCdQzhgwgaQGCyqGSIb3
# DQEJEAIMMYGUMIGRMIGOMIGLBBQxAw4XaqRZLqssi63oMpn8tVhdzzBzMF+kXTBb
# MQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTExMC8GA1UE
# AxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBTSEEzODQgLSBHNAIQAUiQ
# PcKKvKehGU0MHFe4KTANBgkqhkiG9w0BAQsFAASCAYBrQIkSd2RPIYspYKo/Y3nL
# 0SaQFCKAujlG/M8EHk00c6n2fxGqYfgMPtfGxryxTXZ7reYO418C/BxpdzYpk0XJ
# WsLJpcIGf7ExPgZkvGv11eM+5lr88mRJyCac5GLvAiOC6jZsqbWlmFWHo0oWPuQj
# bIBt/JN/LnxEEhEQlA+IA8D8by9xk5VZIUiaegH4kJyjiZ/ugLOFnv/M565t1n2t
# SHkvdg+8FpRCvDX2xqcBvs2T6FyWnzEBJHf90FPJobTCFU8ZEBcUtfBfdGB3y1WO
# b75hJhNOoamp/CWFEhA2wew+KRsgJwpQ2NrwtRxQ+Ib1rlJY/f2vlSIhG4B707MG
# FMqhIv395KRTZQXFYfKRrnH+d8XxC12q2qpVgkK0vtKwLVh3nTq91QGSfO3TauF6
# jpYkZlG9IOLK7uMbS4ezRU2y0T5wd3VuslfnOy2jWQwrVZqz4g8jRAKV2TLRh83M
# GS6I+Lbo7YgH8YXMO+NVTv5J3T7rDUZBWS5YLraSRgg=
# SIG # End signature block
