# QlikNPrinting-CLI

PowerShell module to interact with the [Qlik NPrinting APIs](https://help.qlik.com/en-US/nprinting/csh/Content/NPrinting/Extending/NPrinting-APIs-Reference-Redirect.htm).

Authenticate a session with `Connect-NPrinting`, then use the `Get/New/Set/Remove-NP*`
functions, or call any endpoint directly with `Invoke-NPRequest`.

**Requirements:** Windows PowerShell 5.1 or PowerShell 7+. Network access to the
NPrinting server over HTTP/HTTPS (default port 4993).

Version history is in [CHANGELOG.md](CHANGELOG.md).

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
Once you have an authenticated session, use the `Get-NP*` functions to read, and the
`New-/Set-/Remove-NP*` functions to change objects. A few examples:

```PowerShell
Get-NPUsers -Roles -Groups -Filters      # users, enriched with related objects
Get-NPApps -Name 'Sales*'                # name filtering (supports * wildcard)
Get-NPTasks -Name 'Nightly*' -Executions # tasks with their execution history
```

See the [Function reference](#function-reference) for the full command set.

## Function reference

All functions target the **documented public API** (`/api/v1/...`). Write operations
support `-WhatIf`/`-Confirm`; `Remove-*` and `Start-NPTask` default to prompting.

| Area | Functions |
|---|---|
| Session | `Connect-NPrinting`, `Invoke-NPRequest` |
| Apps | `Get-NPApps`, `New-NPApp`, `Set-NPApp`, `Export-NPAppTemplates` |
| Connections | `Get-NPConnections`, `New-NPConnection`, `Set-NPConnection`, `Invoke-NPConnectionReload` |
| Filters | `Get-NPFilters`, `New-NPFilter`, `Set-NPFilter`, `Remove-NPFilter` |
| Groups | `Get-NPGroups`, `New-NPGroup`, `Set-NPGroup`, `Remove-NPGroup` |
| Roles | `Get-NPRoles` |
| Users | `Get-NPUsers`, `New-NPUser`, `Set-NPUser`, `Remove-NPUser` |
| Reports | `Get-NPReports` |
| Tasks | `Get-NPTasks`, `Start-NPTask`, `Get-NPTaskExecutions` |
| On-Demand | `New-NPOnDemandRequest`, `Get-NPOnDemandRequest`, `Get-NPOnDemandResult`, `Remove-NPOnDemandRequest` |
| Audit | `Get-NPAuditEvents`, `Get-NPAuditLogs` |

The natural pattern for updates is **Get → modify → Set**, e.g.:
```PowerShell
$filter = Get-NPFilters | Where-Object name -eq 'Region'
$filter.enabled = $false
Set-NPFilter -Id $filter.id -InputObject $filter
```
Create operations return the new object's `id` and `location`:
```PowerShell
$new = New-NPGroup -Name 'Finance'
$new.id
```

> **Availability varies by NPrinting version and account permissions.** These functions
> follow the current (May 2026) public API. On older NPrinting servers some endpoints or
> required fields differ, and some operations (e.g. creating users/apps) require an
> administrative role — the server will return `403`/`400` if your account or version
> doesn't support them. The reverse-engineered private endpoints (NPrinting Private
> Endpoint) exposed by the web UI are reachable via `Invoke-NPRequest -NPE` where the
> public API doesn't cover a need.

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

##### Get Specific App with ID
```PowerShell
$IDApp = "70d20d7e-d013-4bc0-8398-6f890041f89b"
Invoke-NPRequest -method Get -Path "apps/$IDApp"
```

##### Get All Users
```PowerShell
Invoke-NPRequest -method Get -Path 'users'
```

##### Get Specific User with ID
```PowerShell
$IDUser = "033eeaf0-956e-41fa-83be-f7876479844a"
Invoke-NPRequest -method Get -Path "users/$IDUser"
```

##### Delete Specific User
```PowerShell
Invoke-NPRequest -method Delete -Path "users/$IDUser"
```

##### Update a specific User
```PowerShell
$Data = @{
    UserName = "ChangeName"
}
Invoke-NPRequest -method Put -Path "users/$IDUser" -Data $Data
```

##### Create A New User
```PowerShell
$Data = @{
    password = "changeme"
    email    = "changename@domain.com"
    enabled  = $true
    UserName = "ChangeName"
    timezone = "Australia/Melbourne"
    Locale   = "en"
}
Invoke-NPRequest -method Post -Path "users" -Data $Data
```
> `Invoke-NPRequest` serialises hashtable/object bodies to JSON for you (depth 5 by
> default, configurable with `-Depth`), so you no longer need to call `ConvertTo-Json`
> first — though you still can, as JSON strings are passed through unchanged.

## Development

The module is authored one-function-per-file for readability and clean diffs. The
loader (`QlikNPrinting-CLI.psm1`) dot-sources every file under `src/` at import time
and exports the public functions. To add a function, drop a `.ps1` into the matching
folder.

```
src/
  Public/    # one file per exported function (auto-discovered + exported)
  Private/   # internal helpers (dot-sourced, not exported)
tests/                   # Pester tests
QlikNPrinting-CLI.psm1   # loader
QlikNPrinting-CLI.psd1   # manifest (FunctionsToExport = '*' -> defers to the loader)
.gitattributes           # pins PowerShell files to CRLF so signatures survive git
```

### Test
```PowerShell
Invoke-Pester -Path .\tests
```
Tests mock `Invoke-RestMethod` at the module boundary, so no live NPrinting server
is required.

### Lint
```PowerShell
Invoke-ScriptAnalyzer -Path .\src -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

### Signing

The module is Authenticode-signed. Because the loader dot-sources the `src` files,
the loader, the manifest, **and every source file** are signed (under `AllSigned` each
dot-sourced script is checked individually). `.gitattributes` pins these files to CRLF
so the signed bytes round-trip through clone/checkout.

**Editing any `src/*.ps1`, the loader, or the manifest invalidates that file's
signature** — re-sign after any change:
```PowerShell
$cert  = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
$files = Get-ChildItem -Recurse -Filter *.ps1 -Path .\src
$files += Get-Item .\QlikNPrinting-CLI.psm1, .\QlikNPrinting-CLI.psd1
Set-AuthenticodeSignature -FilePath $files -Certificate $cert `
    -TimestampServer 'http://timestamp.digicert.com'
```
Verify everything is valid:
```PowerShell
Get-AuthenticodeSignature $files | Where-Object Status -ne 'Valid'
```
