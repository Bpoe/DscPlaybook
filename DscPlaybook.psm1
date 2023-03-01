$references = @{}

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

function variables {
    param ([string] $Name)

    Get-Variable -Name $Name -ValueOnly
}

function reference {
    param ([string] $Name)

    $value = $references[$Name]
    return $value
}

function equals {
    param ([string] $Left, [string] $Right)

    return [System.String]::Equals($Left, $Right)
}

function not {
    param ([Boolean] $Statement)

    return $Statement -ne $true
}

function Invoke-DscPlaybook {
    param (
        [string] $FilePath,
        [ValidateSet("Test", "Set")]
        [string] $Mode = "Test"
    )

    $pipeline = get-content $FilePath | ConvertFrom-Yaml

    # Set Env variables from pipeline
    SetVariables -Variables $pipeline.variables

    $references.Clear()

    # Execute Tasks
    foreach ($task in $pipeline.resources) {
        Write-Host ""
        Write-Host "Resource [$($task.type)/$($task.name)]"

        if ($null -ne $task.condition -and (Invoke-Expression $task.condition) -eq $false) {
            Write-Host "skipping" -ForegroundColor Cyan
            continue
        }

        $module = $task.type.Split("/")[0]
        $resourceType = $task.type.Split("/")[1]

        # Install the module if needed
        $installedModule = Get-InstalledModule -Name $module -ErrorAction SilentlyContinue
        if ($null -eq $installedModule) {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            Install-Module -Name $module -Confirm:$false -AcceptLicense -Repository PSGallery
        }

        # Expand variables in the input values
        $Property = @{}
        foreach ($key in $task.properties.Keys) {
            $inputValue = $ExecutionContext.InvokeCommand.ExpandString($task.properties[$key])

            $Property.Add($key, $inputValue)
        }

        $parameters = @{
            Name = $resourceType
            ModuleName = $module
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

        # Register reference
        $parameters.Method = "Get"
        $output_var = Invoke-DscResource @parameters
        $references.Add($task.name, $output_var)
    }
}