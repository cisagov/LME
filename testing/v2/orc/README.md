# Threat emulation notes

The following is a guide to help you create virtual machines to test LME's capabilities and 
do threat testing. It is highly experimental and not guaranteed to work for every system.

Tested on ubuntu 24. Recommend a minimum of 32 GB RAM, 50GB free disk space, multi core processor.


## Setup
This guide will build out testing infrastructure / give an LME demo.

### clone LME: 
```bash
cd ~
git clone https://github.com/cisagov/LME.git
```

### install minimega:
This will install minimega to the /opt directory
```bash
cd LME/testing/v2/installers/minimega
sudo ./install_local.sh
```

### configure qcow windows template:
Install dependencies:
```bash
#might need to install the following:
#     genisoimage wimtools makeisofs 
apt install -y ovmf ansible sshpass python3-venv genisoimage wimtools

cd ~/LME/testing/v2/orc
ansible-galaxy install -r requirements.yml
```

Install isos:
```bash
#https://gitlab.com/badsectorlabs/ludus/-/blob/main/templates/win11-23h2-x64-enterprise/win11-23h2-x64-enterprise.pkr.hcl
mkdir -p ~/LME/testing/v2/orc/files/isos
cd ~/LME/testing/v2/orc/files/isos/

wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.240-1/virtio-win-0.1.240.iso
wget -O win11.iso https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/22631.2428.231001-0608.23H2_NI_RELEASE_SVC_REFRESH_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso
wget https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso
```

Setup drivers directory for packer to use: 
```bash
cd ~/LME/testing/v2/orc/files/isos/

mkdir -p tmp virtio-drivers
sudo mount -o loop virtio-win-0.1.240.iso tmp
cp -r tmp/* ./virtio-drivers/
sudo umount tmp
chmod -R 755 ./virtio-drivers/
```

Setup venv for most up to date ansible: 
```bash
cd ~/LME/testing/v2/orc
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install ansible-core #>=2.15.0
```

### download packer:
```bash
VERSION=1.12.0
wget https://releases.hashicorp.com/packer/${VERSION}/packer_${VERSION}_linux_amd64.zip
unzip packer_${VERSION}_linux_amd64.zip
sudo mv packer /usr/local/bin/
rm packer_${VERSION}_linux_amd64.zip
rm LICENSE.txt
```

Configure user to be in kvm group, so we don't ahve to build with root: 
```bash
sudo usermod -a -G kvm $USER
#if that doesn't work you can temporarily modify the device file access, don't do this permanently: 
sudo chmod 666 /dev/kvm
#TODO make sure to add notes to show what it was before:
```

#### notes for converting ludus template into LME packer template: 
```
https://gitlab.com/badsectorlabs/ludus.git
```

## build qcow images: 
All vms have user/password: `localuser/password`

### install packer plugins:
```bash
cd ~/LME/testing/v2/orc/templates/
packer init .
```

### windows:
**NOTE**: check that the file /usr/share/OVMF/OVMF_CODE.fd. On newer machines the file might be OVMF_CODE_4M.fd.
If it is not OVMF_CODE.fd, open win11-23h2-x64-enterprise.pkr.hcl and change lines 85 and 86 to use the _4M.fd suffix.
The packer build will fail if the path is not set.

Modify the variables in example_vars.pkrvars.hcl to point to the correct paths.
```bash
cd ~/LME/testing/v2/orc/templates/win11-23h2-x64-enterprise
#TODO modify example-variables to correct paths 
PACKER_LOG=1 packer build --var-file=./example_vars.pkrvars.hcl ./win11-23h2-x64-enterprise.pkr.hcl
```

### linux:
Modify the variables in example_vars.pkrvars.hcl to point to the correct paths.
```bash
cd ./ubuntu-24.04-x64-server/
#TODO modify example-variables to correct paths. Can also change name of output VM 
mkdir -p /tmp/lme/ansible_state/{cp,tmp,pc}
PACKER_LOG=1 packer build --var-file=./example_vars.pkrvars.hcl ./ubuntu-24.04-x64-server.pkr.hcl
```

## generate minimega mm network: 

At this point both VMs will have been created using packer. 

### give the network internet: 
To give machine internet connectivity, run the following on the host machine:

```bash
export WAN=eth1 #internet interface, could be eno1 or something else
export INTERNAL=mega_bridge #if mega_bridge does not work, change to mega_tapN, where N is the number of the tap you are using

# this sets up packet forwarding from 
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
sudo iptables -A FORWARD -i $INTERNAL -o $WAN -j ACCEPT
sudo iptables -A FORWARD -i $WAN -o $INTERNAL -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### boot up the network: 

Attach to the minimega console
```bash
sudo /opt/minimega/bin/minimega --attach
```

The following commands are run from within the minimega shell.

Set up experiment network. Creates a router for the minimega experiment that will
provide IP addresses to the machines. Set up a static mapping (or skip to use DHCP).
Configure the dns server to point to 1.1.1.1 (for VM DNS).
```minimega
tap create EXP ip 10.0.1.1/24
shell sleep 5
dnsmasq start 10.0.1.1 10.0.1.2 10.0.1.254


#check the dnsmasq id, should be 0 if you have not run dnsmasq yet. If not 0,
# change the id in the following lines 

#configures static ip addresses. 10.0.1.7 will be our linux box, 10.0.1.5 will be our windows.
# feel free to add more static configurations. If you do not do this DHCP will be used.
dnsmasq configure 0 ip 00:11:22:33:44:55 10.0.1.5
dnsmasq configure 0 ip 66:77:88:99:aa:bb 10.0.1.7
dnsmasq configure 0 dns upstream server 1.1.1.1
```

Configure and deploy the VMs. Paths are assuming LME was installed in home directory, change as needed.
```minimega
#windows
clear vm config
vm config disk ~/LME/testing/v2/orc/files/win11/win11
vm config snapshot true
vm config memory 8192
vm config vcpus 4
vm config machine q35

# check /usr/share/OVMF/OVMF_CODE.fd. On newer machines the file might be OVMF_CODE_4M.fd. If so, change the following line
vm config qemu-append -drive file=/usr/share/OVMF/OVMF_CODE.fd,if=pflash,unit=0,format=raw,readonly=on -drive file=~/LME/testing/v2/orc/files/win11/efivars.fd,if=pflash,unit=1,format=raw
vm config net EXP,00:11:22:33:44:55
vm launch kvm windows1

#ubuntu configuration
clear vm config
vm config disk ~/LME/testing/v2/orc/files/ubuntu-24.04/ubuntu-24.04
vm config snapshot true
vm config memory 16384
vm config vcpus 4
vm config net EXP,66:77:88:99:aa:bb
vm launch kvm ubuntu1

vm start all
```

Now the VMs will launch. You can view them in a browser using miniweb on port 9001.

## Install LME

Once the VMs are booted 

#### Install LME:
The file ./inventory.ini is configured assuming the static IPs were configured as above,
namely windows = 10.0.1.5 and linux = 10.0.1.7. If these are different please edit the
inventory file.
```bash
cd ~/LME/testing/v2/orc
ansible-playbook -i inventory.ini ./playbooks/install_lme.yml
#TODO: get roles working that install wazuh+elastic agents
#TODO: get roles working that install caldera server + caldera agents
```


# DEBUG / FAQ / HELP 
 
## minimega errors:
errors will be in tags, if unable to connect, that means a path is probably wrong
```
sudo /opt/minimega/bin/minimega -e .columns name,tap,ip,tags vm info
```

## view the process of the build: 
host
```bash
#install novnc via your favorite manager, I like nix: https://search.nixos.org/packages?channel=unstable&show=novnc&from=0&size=50&sort=relevance&type=packages&query=novnc
ssh -L 5998:127.0.0.1:5998  HOST
novnc --vnc localhost:5998
```

server:
 - make sure the port you set in the packer build file is available for vnc

## errors with packer build
### windows
If /usr/share/OVMF/OVMF_CODE.fd and OVMF_VARS.fd do not exist the build will fail.
Update the script to use /usr/share/OVMF/OVMF_CODE_4M.fd and OVMF_VARS_4M.fd, or whatever
version of the files exists.

## ansible issues
### Can't ssh onto machine
Sometimes the packer VM doesn't have ssh working. Log on to the VM using VNC (go to localhost:9001, click on VNC for VM).
Log in as `localuser`/`password` and run:
```bash
sudo service regenerate_ssh_host_keys start
sudo service ssh restart
```
Ssh should now work

### ansible can't use user/password because ssh profile not a known host
ssh into the linux vm manually to add it to known_hosts file
```bash
ssh localuser@10.0.1.7
```

## Endpoint Setup
See README in /playbooks/endpoint_setup for detailed information on deploying agents and sysmon to endpoints using ansible. This is currently a manual process that needs to be configured to be automated and more dynamic.
