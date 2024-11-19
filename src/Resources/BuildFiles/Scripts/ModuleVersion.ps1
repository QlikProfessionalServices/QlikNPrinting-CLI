function Get-ModuleVersion {
    param (
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Config,
        [int]$Major,
        [int]$Minor,
        [int]$Build,
        [int]$Revision
    )

    # Set the Version
    if ($null -ne $Config.ModuleManifest.ModuleVersion) {
        $ModuleVersion = $Config.ModuleManifest.ModuleVersion
    } else {
        try {
            $Tag = $(git tag -l --sort=refname v* | Select-Object -Last 1)
        } catch {
            $Tag = 'v0.0.0.0'
        }
        if ($null -eq $Tag) {
            $Tag = 'v0.0.0.0'
        }
        try {
            $Version = [version]::new(($Tag).substring(1))
        } catch {
            $Version = [version]::new('0.0.0.0')
        }
        $Major = if ($PSBoundParameters.ContainsKey('Major')) { $Major } else { $Version.Major }
        $Minor = if ($PSBoundParameters.ContainsKey('Minor')) { $Minor } else { $Version.Minor }
        $Year = [datetime]::UtcNow.Year
        $DayOfYear = [datetime]::UtcNow.DayOfYear
        $Build = if ($PSBoundParameters.ContainsKey('Build')) { $Build } else { '{0:D2}{1:D3}' -f ($Year % 100), $DayOfYear }
        $Revision = if ($PSBoundParameters.ContainsKey('Revision')) { $Revision } else { [datetime]::UtcNow.TimeOfDay.TotalSeconds.ToString('#')/2 }
        $ModuleVersion = [version]::new("$Major.$Minor.$Build.$Revision")
    }
    return $ModuleVersion
}