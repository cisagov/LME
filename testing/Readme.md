# SetupTestbed.ps1
This script creates a "blank slate" for testing/configuring LME.

Using the Azure CLI, it creates the following:
- A resource group
- A virtual network, subnet, and network security group
- 2 VMs: "DC1," a Windows server, and "LS1," a Linux server
- Client VMs: Windows clients "C1", "C2", etc. up to 16 based on user input 
- Promotes DC1 to a domain controller
- Adds C1 to the managed domain
- Adds a DNS entry pointing to LS1

This script does not install LME; it simply creates a fresh environment that's ready to have LME installed.

## Usage
| **Parameter**      | **Alias** | **Description**                                                                                                                                                   | **Required** |
|--------------------|-----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------|
| $ResourceGroup     | -g        | The name of the resource group that will be created for storing all testbed resources.                                                                            | Yes          |
| $NumClients        | -n        | The number of Windows clients to create; maximum 16; defaults to 2                                                                                                | No           |
| $AutoShutdownTime  |           | The auto-shutdown time in UTC (HHMM, e.g. 2230, 0000, 1900); auto-shutdown not configured if not provided                                                         | No           |
| $AutoShutdownEmail |           | An email to be notified if a VM is auto-shutdown.                                                                                                                 | No           |
| $AllowedSources    | -s        | Comma-Separated list of CIDR prefixes or IP ranges, e.g. XX.XX.XX.XX/YY,XX.XX.XX.XX/YY,etc..., that are allowed to connect to the VMs via RDP and ssh.            | Yes          |
| $Location          | -l        | The region you would like to build the assets in. Defaults to westus                                                                                              | No           |
| $NoPrompt          | -y        | Switch, run the script with no prompt (useful for automated runs). By default, the script will prompt the user to review paramters and confirm before continuing. | No           |
| $LinuxOnly         | -m        | Run a minimal install of only the linux server                                                                                                                    | No           |

Example:
```
./SetupTestbed.ps1 -ResourceGroup Example1 -NumClients 2 -AutoShutdownTime 0000 -AllowedSources "1.2.3.4,1.2.3.5" -y
```

## Running Using Azure Shell
| **#** | **Step**                                                                                                                                                                                                                                      | **Screenshot**                                          |
|-------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| 1     | Open a cloud shell by navigating to portal.azure.com and clicking the shell icon.                                                                                                                                                             | ![image](/docs/imgs/testing-screenshots/shell.png)      |
| 2     | Select PowerShell.                                                                                                                                                                                                                            | ![image](/docs/imgs/testing-secreenshots/shell2.png)    |
| 3     | Clone the repo `git clone https://github.com/cisagov/LME.git` and then `cd LME\testing`                                                                                                                                                       |  |
| 4     | Run the script, providing values for the parameters when promoted (see [Usage](#usage)). The script will take ~20 minutes to run to completion.                                                                                               | ![image](/docs/imgs/testing-screenshots/shell4.png)     |
| 5     | Save the login credentials printed to the terminal at the end (They will also be in a file called `<$ResourceGroup>.password.txt`). At this point you can login to each VM using RDP (for the Windows servers) or SSH (for the Linux server). | ![image](/docs/imgs/testing-screenshots/shell5.png)     |
| 6     | When you're done testing, simply delete the resource group to clean up all resources created.                                                                                                                                                 | ![image](/docs/imgs/testing-screenshots/delete.png)     |

# Extra Functionality:
 
## Clean Up ResourceGroup: 

1. open a shell like before 
2. run command: `az group delete --name [NAME_YOUP_ROVIDED_ABOVE]`

## Disable Internet: 
Run the following commands in the azure shell.  

```powershell
./internet_toggle.ps1 -RG [NAME_YOU_PROVIDED_ABOVE] [-NSG OPTIONAL_NSG_GROUP] [-enable]
```

Flags:
  - enable: deletes the DENYINTERNET/DENYLOADBALANCER rules
  - NSG: sets NSG to a custom NSG if desired [NSG1 default]

## Install LME on the cluster:
### InstallTestbed.ps1
## Usage
| **Parameter**     | **Alias** | **Description**                                                                        | **Required** |
|-------------------|-----------|----------------------------------------------------------------------------------------|--------------|
| $ResourceGroup    | -g        | The name of the resource group that will be created for storing all testbed resources. | Yes          |
| $NumClients       | -n        | The number of Windows clients you have created; defaults to 2                          | No           |
| $DomainController | -w        | The name of the domain controller in the cluster; defaults to "DC1"                    | No           |
| $LinuxVm          | -l        | The name of the linux server in the cluster; defaults to "LS1"                         | No           |
| $LinuxOnly        | -m        | Run a minimal install of only the linux server                                         | No           |
| $Version          | -v        | Optionally provide a version to install if you want a specific one. `-v 1.3.2`         | No           |
| $Branch           | -b        | Optionally provide a branch to install if you want a specific one   `-b your_branch`   | No           |

Example:
```
./InstallTestbed.ps1 -ResourceGroup YourResourceGroup 
# Or if you want to save the output to a file
./InstallTestbed.ps1 -ResourceGroup YourResourceGroup  | Tee-Object -FilePath "./YourResourceGroup.output.log"
```
| **#** | **Step**                                                                                                                                                  | **Screenshot**                                        |
|-------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| 1     | Open a cloud shell by navigating to portal.azure.com and clicking the shell icon.                                                                         | ![image](/docs/imgs/testing-screenshots/shell.png)    |
| 2     | Select PowerShell.                                                                                                                                        | ![image](/docs/imgs/testing-secreenshots/shell2.png)  |
| 3.a   | If you have already cloned the LME repo then make sure you are in the  `LME\testing` directory and run git pull before changing to the testing directory. |                                                       |
| 3.b   | If you haven't cloned it, clone the github repo in the home directory. `git clone https://github.com/cisagov/LME.git` and then `cd LME\testing`.          |                                                       |
| 4     | Now you can run one of the commands from the Examples above.                                                                                              |                                                       |
| 5     | Save the login credentials printed to the terminal at the end. *See note*                                                                                 |                                                       |
| 6     | When you're done testing, simply delete the resource group to clean up all resources created.                                                             |                                                       |

Note: When the script finishes you will be in the azure_scripts directory, and you should see the elasticsearch credentials printed to the terminal. 
You will need to `cd ../../` to get back to the LME directory. All the passwords should also be in the `<$ResourceGroup>.password.txt` file.


