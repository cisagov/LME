# Installation Guide
#### Attention: Run these commands in the order presented in this document. Some commands depend on variables set in previous commands. Not all commands need to be run. There are some optional commands depending on the testing scenario.

**Note:** This guide supports both **Ubuntu 22.04** (default) and **Red Hat Enterprise Linux 9** as base operating systems. Use the `--use-rhel` flag to deploy RHEL instead of Ubuntu.

## Initial Setup Variables
First, set these variables in your terminal:

```bash
# Required variables
export RESOURCE_GROUP="your-group-name"
export PUBLIC_IP="your-effective-public-ip/32"  # Get this from https://www.whatismyip.com/
export VM_SIZE="Standard_D8_v4"
export LOCATION="westus"
export AUTO_SHUTDOWN_TIME="00:00"
export LME_USER="lme-user"
```

You'll need to follow the steps in [Azure Authentication](/testing/v2/installers/azure/build_azure_linux_network.md#authentication) and 
[Python Setup](/testing/v2/installers/azure/build_azure_linux_network.md#setup) prior to running the steps below.

## Quick Start
All commands are run from the installer directory:

```bash
cd testing/v2/installers
```

### Creating Azure Machine(s)

#### Ubuntu Linux (default):
```bash
./azure/build_azure_linux_network.py -g $RESOURCE_GROUP -s $PUBLIC_IP -vs $VM_SIZE -l $LOCATION -ast $AUTO_SHUTDOWN_TIME
```

#### Red Hat Enterprise Linux 9:
```bash
./azure/build_azure_linux_network.py -g $RESOURCE_GROUP -s $PUBLIC_IP -vs $VM_SIZE -l $LOCATION -ast $AUTO_SHUTDOWN_TIME --use-rhel
```

#### Linux and Windows (add the -w flag to either Ubuntu or RHEL):
Ubuntu + Windows:
```bash
./azure/build_azure_linux_network.py -g $RESOURCE_GROUP -s $PUBLIC_IP -vs $VM_SIZE -l $LOCATION -ast $AUTO_SHUTDOWN_TIME -w
```

RHEL + Windows:
```bash
./azure/build_azure_linux_network.py -g $RESOURCE_GROUP -s $PUBLIC_IP -vs $VM_SIZE -l $LOCATION -ast $AUTO_SHUTDOWN_TIME --use-rhel -w
```

After VM creation, set these additional variables:
```bash
# These are generated during VM creation
export VM_IP=$(cat $RESOURCE_GROUP.ip.txt)
export VM_PASSWORD=$(cat $RESOURCE_GROUP.password.txt)
echo $VM_IP
echo $VM_PASSWORD
```

### Installing lme-v2

#### Ubuntu Linux (default):
```bash
./install_v2/install.sh $LME_USER $VM_IP $RESOURCE_GROUP.password.txt your-branch-name 
```

#### Red Hat Enterprise Linux:
```bash
./install_v2/install_rhel.sh $LME_USER $VM_IP $RESOURCE_GROUP.password.txt your-branch-name 
```

## Setting Up Minimega Clients

### Connecting to VMs

#### You connect to these from the host azure machine

To connect to the Ubuntu machine:
```bash
sudo su
minimega -e vm info
# Find the ip of the ubuntu machine
ssh vmuser@<ip>  # Password: vmuser
```

For web UI access: Browse to http://host-machine-ip:9001
- Ubuntu credentials: `vmuser`/`vmuser`
- Windows credentials: `Admin`/`minimega!1`

To SSH into Windows:
```bash
ssh Test@<ip>  # Password: minimega!1
```

### Installing Minimega Service
```bash
./minimega/install.sh $LME_USER $VM_IP $RESOURCE_GROUP.password.txt
```

### Setting Up Ubuntu Minimega VMs
```bash
./ubuntu_qcow_maker/install.sh $LME_USER $VM_IP $RESOURCE_GROUP.password.txt
```

### Setting Up Windows Minimega VMs
1. Set up the environment file:
```bash
cp ./windows_qcow/.env.example ./windows_qcow/.env
# Edit the .env file and update your resource group name
```

2. Install Windows VM:
```bash
scp -r windows_qcow ubuntu_qcow_maker $LME_USER@$VM_IP:/home/$LME_USER
ssh $LME_USER@$VM_IP 
cd /home/lme-user/windows_qcow
sudo ./install_local.sh
# Follow the device code login prompts
# Press enter for subscription and tenant prompts
```

## Optional: Alternative Linux Distributions

Remember to activate venv first:
```bash
source ~/LME/venv/bin/activate
```

### Ubuntu 24.04 Setup
```bash
./azure/build_azure_linux_network.py \
    -g $RESOURCE_GROUP \
    -s "0.0.0.0/0" \
    -vs $VM_SIZE \
    -l $LOCATION \
    -ast $AUTO_SHUTDOWN_TIME \
    -pub Canonical \
    -io ubuntu-24_04-lts \
    -is server \
    --no-prompt
```


## Creating Additional VMs (Non-Network Attack Scenarios)

### Windows VM
First, set a secure password for the Windows VM:
```bash
export WINDOWS_PASSWORD="SecurePass123!"  # Must contain 12+ chars, uppercase, lowercase, numbers, and symbols
```
```bash
az vm create \
    --resource-group $RESOURCE_GROUP \
    --nsg NSG1 \
    --image Win2019Datacenter \
    --admin-username admin-user \
    --admin-password $WINDOWS_PASSWORD \
    --vnet-name VNet1 \
    --subnet SNet1 \
    --public-ip-sku Standard \
    --name WINDOWS
```

### Ubuntu VM
Note: Use the $VM_PASSWORD that was set earlier after initial VM creation (see "After VM creation, set these additional variables" section above)
```bash
az vm create \
    --resource-group $RESOURCE_GROUP \
    --nsg NSG1 \
    --image Ubuntu2204 \
    --admin-username admin-user \
    --admin-password $VM_PASSWORD \
    --vnet-name VNet1 \
    --subnet SNet1 \
    --public-ip-sku Standard \
    --name linux-client
```