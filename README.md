# PowerShell DSC Configuration
**DscConfiguration** is a PowerShell module that allows you to author a "Configuration" of different DSC resources to be executed in sequence. It supports variables and conditional task execution.

The purpose of this is to demonstrate a simplier authoring experience for PowerShell DSC using YAML/JSON. The schema of the Configuration is based on Azure Templates to allow for easier adoption.

A native DSC configuration usually needs to be written in PowerShell and compiled into a MOF file. No one likes working with MOFs and adding an intermediary file makes editting slower and more complicated. The included "Invoke-DscConfiguration" function will parse the YAML/JSON and directly execute the DSC resources without compiling to a MOF first. This makes the Configuration much more dynamic than a traditional DSC configuration since it can use runtime variables and condititions to control the behavior of its tasks.

Note: This is a very rough Proof of Concept only and should not be used for production purposes.

See TestConfiguration.yaml for a sample configuration. By default it will run in Test mode. Use the `-Mode Set` parameter to run in Set mode.

Usage:
```
Import-Module .\DscConfiguration
Invoke-DscConfiguration .\DscPlaybook\TestConfiguration.yaml
```

Example output:
```
Resource [PSDscResources/User/test-user]
change needed

Resource [PSDscResources/Group/test-group]
skipping

Resource [PSDscResources/Service/spooler-service]
ok

Resource [xTimeZone/xTimeZone/timezone]
ok
```
