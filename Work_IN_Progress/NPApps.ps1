
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