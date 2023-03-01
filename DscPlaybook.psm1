$references = @{}
$variables = @{}
$parameters = @{}

function SetVariables {
    param (
        [hashtable] $Source,
        [hashtable] $Target
    )
    
    foreach ($key in $Source.Keys) {
        $Target.Add($key, $Source[$key])

        $varName = $key.Replace(".", "_")
        New-Variable -Name $varName -Value $Source[$key] -Scope Script -Force | Out-Null
        New-Item -Path env:$varName -Value $Source[$key] -ErrorAction SilentlyContinue
    }
}

function GetDefaultValues {
    param (
        [hashtable] $Source
    )
    
    $values = @{}
    foreach ($key in $Source.Keys) {
        $values.Add($key, $Source[$key].defaultValue)
    }

    return $values
}

function parameters {
    param ([string] $Name)

    $value = $parameters[$Name]
    return $value
}

function variables {
    param ([string] $Name)

    $value = $variables[$Name]
    return $value
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

    $fileExtension = [System.IO.Path]::GetExtension($FilePath)

    if ($fileExtension -eq ".yaml" -or $fileExtension -eq ".yml") {
        $pipeline = get-content $FilePath | ConvertFrom-Yaml
    }
    elseif ($fileExtension -eq ".json") {
        $pipeline = get-content $FilePath | ConvertFrom-Json -AsHashtable
    }

    $parameters.Clear()
    $variables.Clear()
    $references.Clear()

    $defaultValues = GetDefaultValues -Source $pipeline.parameters
    SetVariables -Source $pipeline.variables -Target $variables
    SetVariables -Source $defaultValues -Target $parameters

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

        $resourceParameters = @{
            Name = $resourceType
            ModuleName = $module
            Method = "Test"
            Property = $Property
        }

        $resourceParameters

        # Execute Test for task
        $result = Invoke-DscResource @resourceParameters
        if ($result.InDesiredState) {
            Write-Host "ok" -ForegroundColor Green
        }
        elseif ($Mode -eq "Set") {
            $resourceParameters.Method = "Set"
            try {
                Invoke-DscResource @resourceParameters
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
        $resourceParameters.Method = "Get"
        $output_var = Invoke-DscResource @resourceParameters
        $references.Add($task.name, $output_var)
    }
}
