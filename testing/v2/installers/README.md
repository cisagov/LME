There are readmes for each of the installer directories.

You'll need to follow the steps in [Azure Authentication](/testing/v2/installers/azure/build_azure_linux_network.md#authentication) and 
[Python Setup](/testing/v2/installers/azure/build_azure_linux_network.md#setup) prior to running the steps below. 

## Quick Start
All commands are run from the installer directory. You need to do them in the order below.

```bash
cd testing/v2/installers
```

You can get your effective public ip by browsing to https://www.whatismyip.com/

#### Creating the azure machine(s).
Linux only:
```bash
./azure/build_azure_linux_network.py -g your-group-name -s your-effective-public-ip/32 -vs Standard_D8_v4 -l westus -ast 00:00
```
Linux and a windows machine (just add the -w flag):
```bash
./azure/build_azure_linux_network.py -g your-group-name -s your-effective-public-ip/32 -vs Standard_D8_v4 -l westus -ast 00:00 -w
```

Installing lme-v2
```bash
./install_v2/install.sh lme-user $(cat your-group-name.ip.txt) your-group-name.password.txt branch 
```

### For nasty network attacks you can create minimega clients. 
To connect to the ubuntu machine (after it is created) you can use the following command:
```bash
sudo su
minimega -e vm info
# Find the ip of the ubuntu machine
ssh vmuser@<ip>
```
You can also connect to the ubuntu machine using the web ui. Browse to the host machine's ip in a web browser http://host-machine-ip:9001. You should see the ubuntu machine listed. 
The user is `vmuser` and the password is `vmuser`. You can't copy and paste in the vnc session, so I usually use ssh instead. 


To connect to the windows machine (after it is created) you can browse to the host machine's ip in a web browser http://host-machine-ip:9001. You should see the windows machine listed. 
You can click the connect button to connect to the machine. The username and password for the 
windows machine is `Admin` and the password is `minimega!1`. If you want to ssh into the windows 
machine you can use the following command:
```bash
ssh Test@<ip>
# password is minimega!1
```

Install the minimega service on the remote machine.
```bash
./minimega/install.sh lme-user  $(cat your-group-name.ip.txt) your-group-name.password.txt
```

For Ubuntu minimega clients you can use the qcow2 image. 
```bash
./ubuntu_qcow_maker/install.sh lme-user $(cat your-group-name.ip.txt) your-group-name.password.txt
```

For Windows minimega vms you need to set up the env file.
```bash
cp ./windows_qcow/.env.example ./windows_qcow/.env
# edit the env file and change your resource group name
```

Then you can install the windows minimega vm on the remote machine you will be prompted to login with your device code.
```bash
export user=lme-user
export hostname=$(cat your-group-name.ip.txt)
scp -r windows_qcow ubuntu_qcow_maker $user@$hostname:/home/$user
ssh $user@$hostname 
cd /home/lme-user/windows_qcow
sudo ./install_local.sh
# Do the signing in with your device code
# Just press enter when it asks for the subscription and tenant
# Windows is a big file so it will take a while
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
```bash
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
```bash
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

