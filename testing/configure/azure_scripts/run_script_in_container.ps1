<#
.SYNOPSIS
Executes a specified PowerShell script with arguments on an Azure Virtual Machine.

.DESCRIPTION
This script remotely executes a PowerShell script that is already present on an Azure Virtual Machine (VM),
passing specified arguments to it. It uses Azure's 'az vm run-command invoke' to run the specified script
located on the VM. The script requires the VM name, resource group name, the full path of the script on the VM,
and a string of arguments to pass to the script.

.PARAMETER ResourceGroup
The name of the Azure Resource Group that contains the VM.

.PARAMETER VMName
The name of the Azure Virtual Machine where the script will be executed.

.PARAMETER ScriptPathOnVM
The full path of the PowerShell script on the Azure VM that needs to be executed.

.PARAMETER ScriptArguments
A string of arguments that will be passed to the script.

.EXAMPLE
.\run_script_in_container.ps1 `
    -ResourceGroup "YourResourceGroupName" `
    -VMName "VMName" `
    -ScriptPathOnVM "C:\path\to\your\script.ps1" `
    -ScriptArguments "-Arg1 value1 -Arg2 value2"

This example executes a script located at 'C:\path\to\your\script.ps1' on the VM named "VMName"
 in the resource group "YourResourceGroup", passing it the arguments "-Arg1 value1 -Arg2 value2".

.NOTES
- Ensure that the Azure CLI is installed and configured with the necessary permissions to access and run commands on the specified Azure VM.
- The specified script must exist on the VM and the VM should have the necessary permissions to execute it.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [string]$ScriptPathOnVM,  # The full path of the script on the VM

    [string]$ScriptArguments  # Arguments to pass to the script
)

$InvokeScriptCommand = @"
& '$ScriptPathOnVM' $ScriptArguments
"@

az vm run-command invoke `
    --command-id RunPowerShellScript `
    --resource-group $ResourceGroup `
    --name $VMName `
    --scripts $InvokeScriptCommand
