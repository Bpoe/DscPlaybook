function SetVariables {
    param (
        [hashtable] $Variables
    )
    
    foreach ($key in $Variables.Keys) {
        $varName = $key.Replace(".", "_")
        New-Variable -Name $varName -Value $Variables[$key] -Scope Script -Force | Out-Null
        New-Item -Path env:$varName -Value $Variables[$key] -ErrorAction SilentlyContinue
    }
}

function Invoke-DscPlaybook {
    param (
        [string] $FilePath,
        [ValidateSet("Test", "Set")]
        [string] $Mode = "Test"
    )

    $pipeline = get-content $FilePath | ConvertFrom-Yaml

    # Set Env variables from pipeline
    SetVariables -Variables $pipeline.vars

    Write-Host "PLAY [$($pipeline.name)]"

    # Execute Tasks
    foreach ($task in $pipeline.tasks) {
        Write-Host ""
        Write-Host "TASK [$($task.name)]"

        if ($null -ne $task.when -and (Invoke-Expression $task.when) -eq $false) {
            Write-Host "skipping" -ForegroundColor Cyan
            continue
        }

        # Install the module if needed
        $installedModule = Get-InstalledModule -Name $task.module -ErrorAction SilentlyContinue
        if ($null -eq $installedModule) {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            Install-Module -Name $task.module -Confirm:$false -AcceptLicense -Repository PSGallery
        }

        # Expand variables in the input values
        $Property = @{}
        foreach ($key in $task.settings.Keys) {
            $inputValue = $ExecutionContext.InvokeCommand.ExpandString($task.settings[$key])

            $Property.Add($key, $inputValue)
        }

        $parameters = @{
            Name = $task.resource
            ModuleName = $task.module
            Method = "Test"
            Property = $Property
        }

        # Execute Test for task
        $result = Invoke-DscResource @parameters
        if ($result.InDesiredState) {
            Write-Host "ok" -ForegroundColor Green
        }
        elseif ($Mode -eq "Set") {
            $parameters.Method = "Set"
            try {
                Invoke-DscResource @parameters
                Write-Host "changed" -ForegroundColor Yellow
            }
            catch {
                Write-Host "failed" -ForegroundColor Red
            }
        }
        else {
            Write-Host "change needed" -ForegroundColor Yellow
        }

        if ($null -ne $task.register) {
            $parameters.Method = "Get"
            $output_var = Invoke-DscResource @parameters
            New-Variable -Name $task.register -Value $output_var -Scope Script -Force
        }
    }
}