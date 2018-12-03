
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

	
	.PARAMETER ID
		A description of the ID parameter.
	
	.PARAMETER UserName
		A description of the UserName parameter.
	
	.PARAMETER Email
		A description of the Email parameter.
	
	.PARAMETER roles
		A description of the roles parameter.
	
	.PARAMETER groups
		A description of the groups parameter.
	
	.PARAMETER filters
		A description of the filters parameter.
	
	.EXAMPLE
		Get-NPUsers -roles -groups -filters
		Get-NPUsers -UserName Marc -roles -groups -filters

#>
function Get-NPUsers
{
	[CmdletBinding()]
	param
	(
		[string]$ID,
		[string]$UserName,
		[string]$Email,
		[switch]$roles,
		[switch]$groups,
		[switch]$filters
	)
	
	$Filter = ""
	switch ($PSBoundParameters.Keys)
	{
		ID{ $Filter = GetNPFilter -Filter $Filter -Property "ID" -Value $ID }
		UserName{ $Filter = GetNPFilter -Filter $Filter -Property "UserName" -Value $UserName }
		EMail{ $Filter = GetNPFilter -Filter $Filter -Property "EMail" -Value $EMail }
	}
	$BasePath = "Users"
	$Path = "$($BasePath)$($Filter)"
	$NPUsers = Invoke-NPRequest -Path $Path -method Get
	
	if ($roles.IsPresent)
	{
		Add-NPProperty -Property "Roles" -NPObject $NPUsers -path $BasePath
	}
	if ($groups.IsPresent)
	{
		Add-NPProperty -Property "Groups" -NPObject $NPUsers -path $BasePath
	}
	if ($filters.IsPresent)
	{
		Add-NPProperty -Property "Filters" -NPObject $NPUsers -path $BasePath
	}
	$NPUsers
}