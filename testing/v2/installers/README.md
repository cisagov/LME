There are readmes for each of the installer directories.

You'll need to follow the steps in [Azure Authentication](/testing/v2/installers/azure/build_azure_linux_network.md#authentication) and 
[Python Setup](/testing/v2/installers/azure/build_azure_linux_network.md#setup) prior to running the steps below. 

## Quick Start
All commands are run from the installer directory. 
```bash
cd testing/v2/installers
```

#### Creating the azure machine(s).
Linux only:
```bash
./azure/build_azure_linux_network.py -g your-group-name -s 0.0.0.0 -vs Standard_D8_v4 -l westus -ast 00:00
```
Linux and a windows machine (just add the -w flag):
```bash
./azure/build_azure_linux_network.py -g your-group-name -s 0.0.0.0 -vs Standard_D8_v4 -l westus -ast 00:00 -w
```

Installing lme-v2
```bash
./install_v2/install.sh lme-user $(cat your-group-name.ip.txt) your-group-name.password.txt branch 
```

### For nasty network attacks you can create minimega clients. 

Install the minimega service on the remote machine.
```bash
./minimega/install.sh lme-user  $(cat your-group-name.ip.txt) your-group-name.password.txt
```

For Ubuntu minimega clients you can use the qcow2 image. 
```bash
./ubuntu_qcow_maker/install.sh lme-user $(cat your-group-name.ip.txt) your-group-name.password.txt
```

For Windows minimega vms you need to set up the env file.
```
cp ./windows_qcow/.env.example ./windows_qcow/.env
# edit the env file and change your resource group name
```

Then you can install the windows minimega vm on the remote machine you will be prompted to login with your device code.
```
export user=lme-user
export hostname=$(cat your-group-name.ip.txt)
scp -r windows_qcow ubuntu_qcow_maker $user@$hostname:/home/$user
ssh $user@$hostname 
cd /home/$user/windows_qcow
sudo ./install_local.sh
```
## For a 24.04 machine instead of 22.04 (optional)
Reminder activate venv, from steps above, first: 

`source ~/LME/venv/bin/activate`

Create the network.
```bash
./azure/build_azure_linux_network.py -g your-group-name -s 0.0.0.0 -vs Standard_D8_v4 -l westus -ast 00:00   -pub Canonical  -io 0001-com-ubuntu-server-noble-daily  -is 24_04-daily-lts-gen2
```

## Creating additional virtual machine clients if you aren't going to do nasty network attacks: 
Windows: 
```
az vm create `
  --resource-group xxxxxx `
  --nsg NSG1 `
  --image Win2019Datacenter `
  --admin-username admin-user `
  --admin-password xxxxxxxxxxxxxx `
  --vnet-name VNet1 `
  --subnet SNet1 `
  --public-ip-sku Standard `
  --name WINDOWS
```

Ubuntu:
```
az vm create `
   --resource-group XXXXX `
   --nsg NSG1 `
   --image Ubuntu2204 `      
   --admin-username admin-user `
   --admin-password XXXXXXXX `
   --vnet-name VNet1 `
   --subnet SNet1 `
   --public-ip-sku Standard `
   --name linux-client
```

