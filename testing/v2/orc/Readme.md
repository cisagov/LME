# Scalability testing notes:

Testing completed on an ubuntu 24.04 machine

## Experiment Design:
  - virtualization level: all the logic to define the "physical" experiment network that runs through minimega qemu vms
  - experiment level: all the logic that fits inside the virtualized network, controlled by ansible, and runs the client, server, and router operating systems

### technology:
  - minimega: executes virtual machines, orchestrates the virtualized network infrastructure
  - anisble: configures all machines to be uniform and operating as expected

### machines:
  - linux: clients that sit on the network
  - windows: clients that sit on the network
  - lme: logging made easy server that runs LME service containers
  - caldera: runs caldera to execute attacks

## Layout:
- group_vars/
    - used for ansible
- playbooks/
    - helpful ansible playbooks for configuring VMs
    - NOTE: wazuh needs to be added to the "install_agents.yml"

- roles/
    - more ludus playbooks, not used right now
- templates/
    - packer templates adapted from public ludus templates
- generate.py
    - generates the configurations of minimega files and ansible yaml files
    - also deploys the vms using minimega



##  Setup:
This builds on our testing infrastructure:

### clone LME:
```
export TLD="/home/$USER"
cd $TLD
git clone https://github.com/cisagov/LME.git
```

### install minimega:
This will install minimega to the /opt directory
```
export TLD="/home/$USER/LME"
export FILEPATH=$TLD/files
cd $TLD/testing/v2/installers/minimega
sudo ./install_local.sh
```

### configure qcow windows template:
install dependencies:
```bash
#genisoimage wimtools
apt install -y ovmf ansible sshpass python3-venv genisoimage wimtools pipewire-audio-client-libraries
cd $TLD/testing/v2/orc
ansible-galaxy install -r requirements.yml
ansible-galaxy collection install ansible.windows  community.windows
```

install isos:
```bash
#https://gitlab.com/badsectorlabs/ludus/-/blob/main/templates/win11-23h2-x64-enterprise/win11-23h2-x64-enterprise.pkr.hcl
mkdir -p $FILEPATH/isos/
cd $FILEPATH/isos/
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.240-1/virtio-win-0.1.240.iso
wget https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/22631.2428.231001-0608.23H2_NI_RELEASE_SVC_REFRESH_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso
mv 22631.2428.231001-0608.23H2_NI_RELEASE_SVC_REFRESH_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso win11.iso
wget https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso
```

setup drivers directory for packer to use:
```bash
cd $FILEPATH/isos/
mkdir -p tmp virtio-drivers
sudo mount -o loop virtio-win-0.1.240.iso tmp
cp -r tmp/* ./virtio-drivers/
umount tmp
chmod -R 755 ./virtio-drivers/
```

setup venv for most up to date ansible:
```bash
cd $TLD
sudo apt install python3-venv
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install ansible-core >=2.15.0
```

### download packer:
```
VERSION=1.12.0
wget https://releases.hashicorp.com/packer/${VERSION}/packer_${VERSION}_linux_amd64.zip
unzip packer_${VERSION}_linux_amd64.zip
sudo mv packer /usr/local/bin/
rm packer_${VERSION}_linux_amd64.zip
rm LICENSE.txt
```

configure user to be in kvm group, so we don't ahve to build with root:
```bash
sudo usermod -a -G kvm $USER
#if that doesn't work you can temporarily modify the device file access, don't do this permanently:
sudo chmod 666 /dev/kvm
```

#### notes for converting ludus template into LME packer template:
there are other templates at:  https://gitlab.com/badsectorlabs/ludus.git

remove the proxmox variables and proxmox only functions, replace them with qcow, and you're good to go!

## build qcow images:
All vms have user/password: `localuser/password`

### install packer plugins:
```bash
cd $TLD/orc/templates/
packer init .
```

### windows:
**NOTE**: check that the file /usr/share/OVMF/OVMF_CODE.fd. On newer machines the file might be OVMF_CODE_4M.fd.
If it is not OVMF_CODE.fd, open win11-23h2-x64-enterprise.pkr.hcl and change lines 85 and 86 to use the _4M.fd suffix.
The packer build will fail if the path is not set.

Modify the variables in example_vars.pkrvars.hcl to point to the correct paths.
```bash
cd ./win11-23h2-x64-enterprise/
cp ../example-variables.pkrvars.hcl ./final_vars.pkrvars.hcl
#TODO modify example-variables to the server paths AFTER COPY
PACKER_LOG=1 packer build --var-file=./final_vars.pkrvars.hcl ./win11-23h2-x64-enterprise.pkr.hcl
```

### linux:
Modify the variables in example_vars.pkrvars.hcl to point to the correct paths.
```bash
cd ./ubuntu-24.04-x64-server/
cp ../example-variables.pkrvars.hcl ./final_vars.pkrvars.hcl
source $TLD/.venv/bin/activate
#TODO modify example-variables to the server paths AFTER COPY
mkdir -p ansible_state/{cp,tmp,pc}
PACKER_LOG=1 packer build --var-file=./final_vars.pkrvars.hcl ./ubuntu-24.04-x64-server.pkr.hcl
```

## generate minimega mm network:

### give the network internet:
To give machine internet connectivity, run the following on the host machine:

```bash
#grab WAN from `sudo ip a` output
export WAN=ens18
export INTERNAL=mega_bridge

# this sets up packet forwarding from
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
sudo iptables -A FORWARD -i $INTERNAL -o $WAN -j ACCEPT
sudo iptables -A FORWARD -i $WAN -o $INTERNAL -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## generate experiment:
generate.py will create a directory with all the minimega and ansible setup you need to run the experiment:
```bash
#add more linux/windows hosts as desired
# will create LME and CALDERA boxes as well
source $TLD/.venv/bin/activate
python3 generate.py --windows 1 --linux 1 --network 192.168.0.0/24
```

deploy on minimega using hte output command from above
```bash
STATE="state_y" python3 generate.py --deploy
```

## Ansible:

### Install LME/Caldera:
Make sure your ansible in your venv is the latest version. Ansible has breaking changes between ansible versions.
```bash
$ansible --version
ansible [core 2.19.2]
......
```

Then run this,
```bash
cd ~/LME/testing/v2/orc
export STATE_FILE=./state_y
source $TLD/.venv/bin/activate

#account passwords will print at the end
ansible-playbook -i ${STATE_FILE}/inventory.ini ./playbooks/install_lme.yml
ansible-playbook -i ${STATE_FILE}/inventory.ini ./playbooks/install_caldera.yml
```

### install agents:
You'll need the password from the last step... if you forgot it:
```bash
ansible-playbook -i ${STATE_FILE}/inventory.ini ./playbooks/install_lme.yml --start-at-task "Extract secrets and display accounts"
```

Then, setup the agents:
```bash
cd ~/LME/testing/v2/orc
export STATE_FILE=./state_y
source $TLD/.venv/bin/activate
cd $TLD/ansible

#add your elastic password below:
export $ELASTIC_PASS='bpb91J8!sCAOUlv!3!ibLZJ1fDPYyk'
ansible-playbook -i ${STATE_FILE}/inventory.ini ./playbooks/intall_agents.yml -e
ansible-playbook -i ${STATE_FILE}/inventory.ini ./playbooks/intall_wazuh.yml -e
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

## dnsmasq issues:
Command to run dnsmasq manually if needed
```bash
sudo dnsmasq --no-daemon --bind-interfaces --listen-address=192.168.1.1 --dhcp-range=192.168.1.2,192.168.1.255,255.255.255.0 --dhcp-host=6a:64:ed:f2:60:b1,192.168.1.2 --dhcp-host=5a:ef:ed:36:72:97,192.168.1.3 --dhcp-host=56:92:f9:0b:a3:08,192.168.1.5 --dhcp-host=ee:4e:a3:81:68:7b,192.168.1.4 --server=1.1.1.1 --interface=tap1 --except-interface=lo
sudo /opt/minimega/bin/minimega -e tap create EXP ip 192.168.1.1/24 tap1
```

## Endpoint Setup
See README in /playbooks/endpoint_setup for detailed information on deploying agents and sysmon to endpoints using ansible. This is currently a manual process that needs to be configured to be automated and more dynamic.
