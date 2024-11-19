<#
.SYNOPSIS
    Retrieves the list of NPrinting tasks.

.DESCRIPTION
    The Get-NPTasks function retrieves the list of tasks from the NPrinting server.
    It uses the Invoke-NPRequest function to send a GET request to the 'tasks' endpoint of the NPrinting API.
    Optional parameters can be specified to filter the results.

.PARAMETER ID
    Specifies the ID of the task to retrieve.

.PARAMETER Name
    Specifies the name of the task to filter the results.

.PARAMETER appId
    Specifies the ID of the app to filter the tasks.

.PARAMETER type
    Specifies the type of the task to filter the results.

.PARAMETER Executions
    Specifies whether to include execution details for each task.

.PARAMETER offset
    Specifies the number of tasks to skip before starting to return results.

.PARAMETER limit
    Specifies the maximum number of tasks to retrieve.

.PARAMETER sort
    Specifies the field by which to sort the results.

.EXAMPLE
    Get-NPTasks

    This example retrieves all NPrinting tasks.

.EXAMPLE
    Get-NPTasks -ID "12345"

    This example retrieves the NPrinting task with the specified ID.

.EXAMPLE
    Get-NPTasks -Name "Monthly Report"

    This example retrieves all NPrinting tasks with the name "Monthly Report".

.EXAMPLE
    Get-NPTasks -Executions

    This example retrieves all NPrinting tasks and includes execution details for each task.

.EXAMPLE
    Get-NPTasks -appId "12345"

    This example retrieves all NPrinting tasks for the specified app ID.

.EXAMPLE
    Get-NPTasks -limit 10 -offset 5

    This example retrieves a maximum of 10 NPrinting tasks, skipping the first 5.

.NOTES
    For more information, visit the NPrinting API documentation:
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=60

.LINK
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=60
#>
function Get-NPTasks {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'ByID', HelpMessage = 'Specifies the ID of the task to retrieve.', Mandatory = $true)]
        [string]$ID,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the name of the task to filter the results.')]
        [string]$Name,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the ID of the app to filter the tasks.')]
        [string]$appId,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the type of the task to filter the results.')]
        [string]$type,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies whether to include execution details for each task.')]
        [Parameter(ParameterSetName = 'ByID', HelpMessage = 'Specifies whether to include execution details for each task.')]
        [switch]$Executions,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the number of tasks to skip before starting to return results.')]
        [int32]$offset,

        [Parameter(ParameterSetName = 'Default', HelpMessage = 'Specifies the maximum number of tasks to retrieve.')]
        [int32]$limit
    )

    try {
        # Construct the base path
        $BasePath = 'tasks'
        if ($ID) { 
            $APIPath = "$BasePath/$ID" 
        } else {
            $Filter = ''
            if ($PSBoundParameters.ContainsKey('appId')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'appId' -Value $appId
            }
            if ($PSBoundParameters.ContainsKey('Name')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'name' -Value $Name
            }
            if ($PSBoundParameters.ContainsKey('type')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'type' -Value $type
            }
            if ($PSBoundParameters.ContainsKey('offset')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'offset' -Value $offset.ToString()
            }
            if ($PSBoundParameters.ContainsKey('limit')) {
                $Filter = GetNPFilter -Filter $Filter -Property 'limit' -Value $limit.ToString()
            }
            $APIPath = "$BasePath$Filter"
        }
        Write-Verbose "Request Path: $APIPath"

        # Fetch tasks from the API
        $NPTasks = Invoke-NPRequest -Path $APIPath -method Get

        # Include execution details if requested
        if ($Executions) {
            $NPTasks | ForEach-Object {
                try {
                    $ExecutionPath = "tasks/$($_.id)/Executions"
                    Write-Verbose "Fetching executions for task ID: $($_.id)"
                    $NPTaskExecutions = Invoke-NPRequest -Path $ExecutionPath -method Get

                    # Add executions as a NoteProperty to the task object
                    Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Executions' -Value $NPTaskExecutions -Force
                } catch {
                    Write-Warning "Failed to fetch executions for task ID: $($_.id): $_"
                }
            }
        }

        return $NPTasks
        
    } catch {
        Write-Error "Failed to retrieve NPTasks: $_"
    }
}