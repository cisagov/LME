There are readmes for each of the installer directories.

You'll need to follow the steps in [Azure Authentication](/testing/v2/installers/azure/build_azure_linux_network.md#authentication) and 
[Python Setup](/testing/v2/installers/azure/build_azure_linux_network.md#setup) prior to running the steps below. 

Quick Start

```bash
./azure/build_azure_linux_network.py -g your-group-name -s 0.0.0.0 -vs Standard_D8_v4 -l westus -ast 00:00
./minimega/install.sh lme-user  $(cat your-group-name.ip.txt) your-group-name.password.txt
./ubuntu_qcow_maker/install.sh lme-user $(cat your-group-name.ip.txt) your-group-name.password.txt
```

./azure/build_azure_linux_network.py -g lme-cbaxley-m1 -s 0.0.0.0 -vs Standard_D8_v4 -l westus -ast 00:00   -pub Canonical  -io 0001-com-ubuntu-server-noble-daily  -is 24_04-daily-lts-gen2
