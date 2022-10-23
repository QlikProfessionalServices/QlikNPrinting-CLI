# QlikNPrinting-CLI
[NPrinting API](https://help.qlik.com/en-US/nprinting/csh/Content/NPrinting/Extending/NPrinting-APIs-Reference-Redirect.htm)

## New in 1.0.0.10
Bug Fix: Added missing parameter 

## New in 1.0.0.9
Bug Fix: Json Depth defaults to 5

Minor improvements 

## New in 1.0.0.8
Updated and aligned with PowerShell Gallery

Function: 
- **Invoke-NPRequest**:
  - Added parameters with default values for required -NPE query path parameters

## Installation
### PowerShell Gallery
```PowerShell
Get-PackageProvider -Name NuGet -ForceBootstrap

# Install for all users, requires admin rights
Install-Module QlikNPrinting-CLI

# Install for current user
Install-Module QlikNPrinting-CLI -Scope CurrentUser
```

```PowerShell
# Once Installed you can import the Module
Import-Module QlikNPrinting-CLI
```

### Manually

To manually install the module, download the latest release from [Release](https://github.com/QlikProfessionalServices/QlikNPrinting-CLI/releases/latest)

Extract the Downloaded file into the appropriate module directory, 

You can check the configured paths by checking the output of the command `$env:PSModulePath`

Default locations are
- System Module `C:\Program Files\WindowsPowerShell\Modules`
- User Module `C:\users\<username>\Documents\WindowsPowerShell\Modules`

## Authentication
Simply using 'Connect-NPrinting' will assume that NPrinting is running on the current machine (where you are running the Script from)
It will attempt to connect to NPrinting with the Current Logged on users credentials.
It will use the Default Port and HTTPS for the connection.

```PowerShell
Connect-NPrinting
```

###### Alternatively you can use the following substituting your values for the examples below
```PowerShell
Connect-NPrinting -Computer https://Server:9999
Connect-NPrinting -Prefix https -Computer Server -Port 9999
Connect-NPrinting -Computer https://Server -Port 9999
```

###### If the Server is using a Default Cert, Powershell May not trust it, if that is the case add `-TrustAllCerts`

```PowerShell
Connect-NPrinting -TrustAllCerts
```

###### if you need to use specific credentials to connect to the API's
NTLM Authentication used by default
or NPrinting (user@domain.com) can be selected

```PowerShell
$Creds = Get-Credential
Connect-NPrinting -Credentials $Creds
Connect-NPrinting -TrustAllCerts -Credentials $Creds -AuthScheme NPrinting
```


###### Then putting it all together.

```PowerShell
Connect-NPrinting -Credentials $Creds -TrustAllCerts -Computer https://server:9999
```

## Usage
Once you have successfully established a authenticated NPSession. You can use any of the following module commands:
```PowerShell
Get-NPUsers
Get-NPTasks
Get-NPRoles
Get-NPReports
Get-NPGroups
Get-NPApps
Get-NPFilters
```

## Do More
If you need the ability to do more you can use `Invoke-NPRequest`
The [NPrinting API](https://help.qlik.com/en-US/nprinting/csh/Content/NPrinting/Extending/NPrinting-APIs-Reference-Redirect.htm) lists the available APIs.

e.g 
```PowerShell 
Get /apps/{id}
```

Which can then be used in the following ways

##### Get All Apps
```PowerShell
Invoke-NPRequest -method Get -Path 'apps'
```

##### Get Specific App with ID"
```PowerShell
$IDApp = "70d20d7e-d013-4bc0-8398-6f890041f89b"
Invoke-NPRequest -method Get -Path 'apps/$IDApp'
```

##### Get All Users
```PowerShell
Invoke-NPRequest -method Get -Path 'users'
```

##### Get Specific User with ID
```PowerShell
$IDUser = "033eeaf0-956e-41fa-83be-f7876479844a"
Invoke-NPRequest -method Get -Path 'users/$IDUser'
```

##### Delete Specific User
```PowerShell
Invoke-NPRequest -method Delete -Path 'users/$IDUser'
```

##### Update a specific User
```PowerShell
$Data = @(
UserName = "ChangeName"
)
$DataJSON = $Data|ConvertTo-Json
Invoke-NPRequest -method Put 'users/$IDUser' -Data $DataJSON
```

##### Create A New User
```PowerShell
$Data = @(
password = "changeme"
email = "changename@domain.com"
enabled = $true
UserName = "ChangeName"
timezone = "Australia/Melbourne"
Locale = "en"
)
$DataJSON = $Data|ConvertTo-Json

Invoke-NPRequest -method Post -Path "users" -Data $DataJSON
```

