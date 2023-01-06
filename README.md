# PowerShell DSC Playbook
**DscPlaybook** is a PowerShell module that allows you to author a "playbook" of different DSC resources to be executed in sequence. It supports variables and conditional task execution.

The purpose of this is to demonstrate an Ansible like Playbook authoring experience for PowerShell DSC using YAML. The structure of the Playbook is very similar to Ansible to allow for easier adoption.

A native DSC configuration usually needs to be written in PowerShell and compiled into a MOF file. No one likes working with MOFs and adding an intermediary file makes editting slower and more complicated. The included "Invoke-DscPlaybook" function will parse the YAML and directly execute the DSC resources without compiling to a MOF first. This makes the Playbook much more dynamic than a traditional DSC configuration since it can use runtime variables and condititions to control the behavior of its tasks.

Note: This is a very rough Proof of Concept only and should not be used for production purposes.

See TestPlaybook.yaml for a sample playbook. By default it will run in Test mode. Use the `-Mode Set` parameter to run in Set mode.

Usage:
```
Import-Module .\DscPlaybook
Invoke-DscPlaybook .\DscPlaybook\TestPlaybook.yaml
```

Example output:
```
PLAY [Demo configuration]

TASK [Ensure TestUser exists]
change needed

TASK [Ensure TestGroup exists]
skipping

TASK [Ensure Spooler service exists]
ok

TASK [Ensure Timezone is Pacific]
ok
```
