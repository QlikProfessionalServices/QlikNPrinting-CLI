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

.PARAMETER Executions
    Specifies whether to include execution details for each task.

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

.NOTES
    For more information, visit the NPrinting API documentation:
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=60

.LINK
    https://help.qlik.com/en-US/nprinting/February2024/APIs/NP+API/index.html?page=60
#>
function Get-NPTasks {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = "Specifies the ID of the task to retrieve.")]
        [string]$ID,
        [Parameter(HelpMessage = "Specifies the name of the task to filter the results.")]
        [string]$Name,
        [Parameter(HelpMessage = "Specifies whether to include execution details for each task.")]
        [switch]$Executions
    )

    try {
        # Construct the base path
        $BasePath = 'tasks'
        $Path = if ($ID) { "$BasePath/$ID" } else { $BasePath }

        # Add filter by name if specified
        if ($Name) {
            $Path = "$Path?filter=name eq '$Name'"
        }

        Write-Verbose "Request Path: $Path"

        # Fetch tasks from the API
        $NPTasks = Invoke-NPRequest -Path $Path -method Get

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