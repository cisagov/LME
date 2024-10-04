- [Authentication](#authentication)
- [Setup and Run the Script](#setup-and-run-the-script)
 - [Prerequisites](#prerequisites)
 - [Setup](#setup)
 - [Running the Script](#running-the-script)
 - [Allowed arguments](#allowed-arguments)
 - [Cleanup](#cleanup)

# Azure Authentication

When running the script outside of an Azure environment, you may be prompted to log in interactively if you haven't authenticated previously. The script uses the `DefaultAzureCredential` or `ClientSecretCredential` from the `azure-identity` library, which follows a specific authentication flow:

1. If the `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_CLIENT_SECRET` environment variables are set, the script will use them to authenticate using the `ClientSecretCredential`. This is typically used for non-interactive authentication, such as in automated scripts or CI/CD pipelines.

2. If the environment variables are not set, the script falls back to using the `DefaultAzureCredential`. The `DefaultAzureCredential` tries to authenticate using the following methods, in order:
  - Environment variables: If the `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_CLIENT_SECRET` environment variables are set, it will use them for authentication.
  - Managed identity: If the script is running on an Azure VM or Azure Functions with a managed identity enabled, it will use the managed identity for authentication.
  - Azure CLI: If you have authenticated previously using the Azure CLI (`az login`), it will use the cached credentials from the CLI.
  - Interactive browser authentication: If none of the above methods succeed, it will open a browser window and prompt you to log in interactively.

## Avoiding Interactive Login

If you run the script outside of an Azure environment and you haven't authenticated previously using the Azure CLI or set the necessary environment variables, the script will prompt you to log in interactively through a browser window.

To avoid interactive login, you can do one of the following:

1. Set the `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_CLIENT_SECRET` environment variables with the appropriate values for your Azure service principal. This allows the script to authenticate using the client secret.

2. Authenticate using the Azure CLI by running `az login` before running the script. This will cache your credentials, and the script will use them for authentication.

If you prefer not to be prompted for interactive login, make sure to set the necessary environment variables or authenticate using the Azure CLI beforehand.

## Environment Variables

The following environment variables can be set to provide authentication credentials:

- `AZURE_CLIENT_ID`: The client ID of your Azure service principal.
- `AZURE_TENANT_ID`: The tenant ID of your Azure subscription.
- `AZURE_CLIENT_SECRET`: The client secret associated with your Azure service principal.
- `AZURE_SUBSCRIPTION_ID`: The subscription ID you want to use for creating the resources.

If these environment variables are set, the script will use them for authentication. Otherwise, it will attempt to use the default Azure credential and retrieve the default subscription ID.


# Setup and Run the Script

## Prerequisites

- Python 3.x installed on your system

## Setup

1. Clone the repository or download the script files to your local machine.

2. Open a terminal or command prompt and navigate to the directory where the script files are located.

3. Create a new virtual environment by running the following command:

   ```bash
   python -m venv venv
   ```

   This will create a new virtual environment named `venv` in the current directory.

4. Activate the virtual environment:

   - For macOS and Linux:
     ```
     source venv/bin/activate
     ```

   - For Windows:
     ```
     venv\Scripts\activate
     ```


   You should see `(venv)` prefixed to your terminal prompt, indicating that the virtual environment is active.

5. Install the required packages by running the following command:

   ```
   pip install -r requirements.txt
   ```

   This will install all the necessary packages listed in the `requirements.txt` file.

## Running the Script

To run the script, use the following command:

```bash
python build_azure_linux_network.py -g <resource-group> -s 10.1.1.10/32 -ast 21:00 
```

Replace `<resource-group>` with the desired resource group name and `<allowed-sources>` with the comma-separated list of CIDR prefixes or IP ranges for allowed sources.

Make sure you have the necessary authentication credentials set up before running the script.

## Allowed arguments
| **Parameter**          | **Alias** | **Description**                                                                                 | **Required** | **Default**                     |
|------------------------|-----------|--------------------------------------------------------------------------------------------------|--------------|---------------------------------|
| --resource-group       | -g        | Resource group name                                                                              | Yes          |                                 |
| --allowed-sources      | -s        | Comma-separated list of CIDR prefixes or IP ranges (XX.XX.XX.XX/YY,XX.XX.XX.XX/YY,etc...)        | Yes          |                                 |
| --location             | -l        | Location where the cluster will be built.                                                       | No           | westus                          |
| --no-prompt            | -y        | Run the script with no prompt (useful for automated runs)                                        | No           | False                           |
| --subscription-id      | -sid      | Azure subscription ID. If not provided, the default subscription ID will be used.                | No           |                                 |
| --vnet-name            | -vn       | Virtual network name                                                                             | No           | VNet1                           |
| --vnet-prefix          | -vp       | Virtual network prefix                                                                           | No           | 10.1.0.0/16                     |
| --subnet-name          | -sn       | Subnet name                                                                                      | No           | SNet1                           |
| --subnet-prefix        | -sp       | Subnet prefix                                                                                    | No           | 10.1.0.0/24                     |
| --ls-ip                | -ip       | IP address for the VM                                                                            | No           | 10.1.0.5                        |
| --vm-admin             | -u        | Admin username for the VM                                                                        | No           | lme-user                        |
| --machine-name         | -m        | Name of the VM                                                                                   | No           | ubuntu                          |
| --ports                | -p        | Ports to open                                                                                    | No           | [22]                            |
| --priorities           | -pr       | Priorities for the ports                                                                         | No           | [1001]                          |
| --protocols            | -pt       | Protocols for the ports                                                                          | No           | ['Tcp']                         |
| --vm-size              | -vs       | Size of the virtual machine                                                                      | No           | Standard_E2d_v4                 |
| --image-publisher      | -pub      | Publisher of the VM image                                                                        | No           | Canonical                       |
| --image-offer          | -io       | Offer of the VM image                                                                            | No           | 0001-com-ubuntu-server-jammy    |
| --image-sku            | -is       | SKU of the VM image                                                                              | No           | 22_04-lts-gen2                  |
| --image-version        | -iv       | Version of the VM image                                                                          | No           | latest                          |
| --os-disk-size-gb      | -os       | Size of the OS disk in GB                                                                        | No           | 128                             |
| --auto-shutdown-time   | -ast      | Auto-Shutdown time in UTC (HH:MM, e.g. 22:30, 00:00, 19:00). Convert timezone as necessary.      | No           |                                 |
| --auto-shutdown-email  | -ase      | Auto-shutdown notification email                                                                 | No           |                                 |



## Cleanup

When you're done using the script, you can deactivate the virtual environment by running the following command:

```
deactivate
```

This will deactivate the virtual environment and return you to your normal terminal prompt.
