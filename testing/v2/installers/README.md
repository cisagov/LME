There are readmes for each of the installer directories.

You'll need to follow the steps in [Azure Authentication](/testing/v2/installers/azure/build_azure_linux_network.md#authentication) and 
[Python Setup](/testing/v2/installers/azure/build_azure_linux_network.md#setup) prior to running the steps below. 

Quick Start

```bash
./azure/build_azure_linux_network.py -g your-group-name -s 0.0.0.0 -vs Standard_D8_v4 -l westus -ast 00:00
./minimega/install.sh lme-user  $(cat your-group-name.ip.txt) your-group-name.password.txt
./ubuntu_qcow_maker/install.sh lme-user $(cat your-group-name.ip.txt) your-group-name.password.txt
./install_v2/install.sh lme-user $(cat your-group-name.ip.txt) your-group-name.password.txt branch 
```

#reminder activiate venv first: `source ~/LME/venv/bin/activate`
./azure/build_azure_linux_network.py -g lme-cbaxley-m1 -s 0.0.0.0 -vs Standard_D8_v4 -l westus -ast 00:00   -pub Canonical  -io 0001-com-ubuntu-server-noble-daily  -is 24_04-daily-lts-gen2

## creating clients: 
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

