$DynamicLoading = @'
[System.IO.DirectoryInfo]$modulePath = $PSScriptRoot
[System.IO.DirectoryInfo]$publicFunctionsPath = Join-Path $modulePath -ChildPath 'Public'
[System.IO.DirectoryInfo]$privateFunctionsPath = Join-Path $modulePath -ChildPath 'Private'
[System.IO.DirectoryInfo]$classesPath = Join-Path $modulePath -ChildPath 'Classes'
$aliases = @()
[regex]$FunctionName = [regex]::new('(?<=function )([\w]+-[\w]+)(?>[\s]+\{)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

if ($publicFunctionsPath.Exists) {
    $publicFunctions = Get-ChildItem -Path $publicFunctionsPath.FullName | Where-Object { $_.Extension -eq '.ps1' }
    $publicFunctions | ForEach-Object { . $_.FullName }
    $publicFunctions | ForEach-Object { # Export all of the public functions from this module
        $content = Get-Content $_.FullName
        $functions = $FunctionName.Matches($($content)).ForEach({ $_.Groups[1].value }) | Sort-Object -Unique
        foreach ($function in $functions) {
            # The command has already been sourced in above. Query any defined aliases.
            $alias = Get-Alias -Definition $function -ErrorAction SilentlyContinue
            if ($alias) {
                $aliases += $alias
                Export-ModuleMember -Function $function -Alias $alias
            } else {
                Export-ModuleMember -Function "$($function)"
            }
        }
    }
}
if ($privateFunctionsPath.Exists) {
    Get-ChildItem -Path $privateFunctionsPath.FullName | Where-Object { $_.Extension -eq '.ps1' } | ForEach-Object { . $_.FullName }
}
if ($classesPath.Exists) {
    Get-ChildItem -Path $classesPath.FullName | Where-Object { $_.Extension -eq '.ps1' } | ForEach-Object { . $_.FullName }
}
'@
return $DynamicLoading