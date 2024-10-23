
[![Downloads](https://img.shields.io/github/downloads/cisagov/lme/total.svg)]()



# Logging Made Easy: 

CISA's Logging Made Easy has a self-install tutorial for organizations to gain a basic level of centralized security logging for Windows clients and provide functionality to detect attacks. LME is the integration of multiple open software platforms which come at no cost to users. LME helps users integrate software platforms together to produce an end-to-end logging capability. LME also provides some pre-made configuration files and scripts, although there is the option to do this on your own.

Logging Made Easy can:

- Show where administrative commands are being run on enrolled devices
- See who is using which machine
- In conjunction with threat reports, it is possible to query for the presence of an attacker in the form of Tactics, Techniques and Procedures (TTPs) 

## Disclaimer: 

LME is still in development, and version 2.1 will address scaling out the deployment.

While LME offers SEIM like capabilities, it should be consider a small simple SIEM.

The LME team simplified the process and created clear instruction on what to download and which configugrations to use, and created convinent scripts to auto configure when possible.

LME is not able to comment on or troubleshoot individual installations. If you believe you have have found an issue with the LME code or documentation please submit a GitHub issue. If you have a question about your installation, please look through all open and closed issues to see if it has been addressed before. If not, then submit a [GitHub issue](https://github.com/cisagov/lme/issues) using the Bug Template, ensuring that you provide all the requested information.

For general questions about LME and suggestions, please visit [GitHub Discussions](https://github.com/cisagov/lme/discussions) to add a discussion post.

## Who is Logging Made Easy for?

From single IT administrators with a handful of devices in their network to larger organizations.

LME is suited for for:

- Organizations without [SOC](https://en.wikipedia.org/wiki/Information_security_operations_center), SIEM or any monitoring in place at the moment.
- Organizations that lack the budget, time or understanding to set up a logging system.
- Organizations that that require gathering logs and monitoring IT
-	Organizations that understand LMEs limitiation


## Table of Contents:
-   [Pre-Requisites:](#architecture)
-   [Architecture:](#architecture)
-   [Installation:](#installation)
-   [Deploying Agents:](#deploying-agents)
-   [Password Encryption:](#password-encryption)
-   [Further Documentation & Upgrading:](#documentation)

## Pre-Requisites
If you are unsure you meet the pre-requisites to installing LME, please read our [prerequisites documentation](/docs/markdown/prerequisites.md).
The biggest Pre-requisite is setting up hardware for your ubuntu server with a minimum of `2 processors`, `16gb ram`, and `128gb` of dedicated storage for LME's Elasticsearch database.

## Architecture:
Ubuntu 22.04 server running podman containers setup as podman quadlets controlled via systemd.

### Required Ports:
Ports required are as follows:
 - Elasticsearch: *9200*
 - Kibana: *443,5601*
 - Wazuh: *1514,1515,1516,55000,514*
 - Agent: *8220*

**Kibana NOTE**: 5601 is the default port, and we've set kibana to listen on 443 as well

### Diagram: 

![diagram](/docs/imgs/lme-architecture-v2.jpg)

### why podman?:
Podman is more secure (by default) against container escape attacks than Docker. It also is far more debug and programmer friendly for making containers secure. 

### Containers:
  - setup: runs `/config/setup/init-setup.sh` based on the configuration of dns defined in `/config/setup/instances.yml`. The script will create a CA, underlying certs for each service, and intialize the admin accounts for elasticsearch(user:`elastic`) and kibana(user:`kibana_system`). 
  - elasticsearch: runs the database for LME and indexes all logs
  - kibana: the front end for querying logs,  investigating via dashboards, and managing fleet agents...
  - fleet-server: executes a [elastic agent ](https://github.com/elastic/elastic-agent) in fleet-server mode. It coordinates elastic agents to  gather logs and status from clients. Configuration is inspired by the [elastic-container](https://github.com/peasead/elastic-container) project.
    - Elastic agents provide integrations, have more features than winlogbeat.
  - wazuh-manager: runs the wazuh manager so we can deploy and manage wazuh agents.
    -  Wazuh (open source) gives EDR (Endpoint Detection Response) with security dashboards to cover the security of all of the machines.
  - lme-frontend (*coming in a future release*): will host an api and gui that unifies the architecture behind one interface

### Agents: 
Wazuh agents will enable EDR capabilities, while Elastic agents will enable logging capabilities.

 - https://github.com/wazuh/wazuh-agent   
 - https://github.com/elastic/elastic-agent  

## Installation:
Please ensure you follow all the configuration steps required below.

**Upgrading**:
If you are a previous user of LME and wish to upgrade from 1.4 -> 2.0, please see our [upgrade documentation](/docs/markdown/maintenance/upgrading.md).


### Downloading LME:
**All steps will assume you start in your cloned directory of LME on your ubuntu 22.04 server**

We suggest you install the latest release version of Logging made easy using the following commands: 

Install Requirements
```
sudo apt update && sudo apt install curl jq unzip -y
```
Download and Unzip the latest version of LME. This will add a path to ~/LME with all requires files.
```
curl -s https://api.github.com/repos/cisagov/LME/releases/latest | jq -r '.assets[0].browser_download_url' | xargs -I {} sh -c 'curl -L -O {} && unzip -d ~/LME $(basename {})'
```

### Operating system: **Ubuntu 22.04**:
Make sure you run an install on ubuntu 22.04, thats the operating system which has been tested the most. 
In theory, you can install LME on any nix... but we've only tested and run installs on 22.04.

### Configuration

Configuration is `/config/`
in `setup` find the configuration for certificate generation and password setting.  
`instances.yml` defines the certificates that will get created.    
The shellscripts initialize accounts and create certificates, and will run from their respective quadlet definitions `lme-setup-accts` and `lme-setup-certs` respectively.
 
Quadlet configuration for containers is in: `/quadlet/`. These are mapped to the root's systemd unit files, but will execute as a non-privileged user.

\***TO EDIT**:\*
The only file that really needs to be touched is creating `/config/lme-environment.env`, which sets up the required environment variables
Get your IP address via the following command: 
```
hostname -I | awk '{print $1}'
```

Setup the config via the following  steps:
```
cp ./config/example.env ./config/lme-environment.env
#update the following values:
IPVAR=127.0.0.1 #your hosts ip 
```



### **Automated Install**

You can run this installer to run the total install in ansible. 

```bash
sudo apt update && sudo apt install -y ansible
# cd ~/LME-PRIV/lme-2-arch # Or path to your clone of this repo
ansible-playbook ./ansible/install_lme_local.yml
```
This assumes that you have the repo in `~/LME/`. 

If you don't, you can pass the `CLONE_DIRECTORY` variable to the playbook. 
```
ansible-playbook ./ansible/install_lme_local.yml -e "clone_dir=/path/to/clone/directory" 
```

This also assumes your user can sudo without a password. If you need to input a password when you sudo, you can run it with the `-K` flag and it will prompt you for a password. 

#### Steps performed in automated install: 
TODO finalize this with more words 

1. Setup /opt/lme, check sudo, and configure other required directories/files
2. Setup password information
3. Setup Nix
4. set service user passwords
5. Install Quadlets
6. Setup Containers for root: The contianers listed in `$clone_directory/config/containers.txt` will be pulled and tagged
7. Start lme.service

#### NOTES:

1. `/opt/lme` will be owned by root, all lme services will run and execute as unprivileged users. The active lme configuration is stored in `/opt/lme/config`.
 
2. Other relevant directories are listed here: 
- `/root/.config/containers/containers.conf`: LME will setup a custom podman configuration for secrets management via [ansible vault](https://docs.ansible.com/ansible/latest/cli/ansible-vault.html).
- `/etc/lme`: storage directory for the master password and user password vault
- `/etc/lme/pass.sh`: the master password file
- `/etc/containers/systemd`: directory where LME installs its quadlet service files
- `/etc/systemd/system`: directory where lme.service is installed
 
3. the master password will be stored at `/etc/lme/pass.sh` and owned by root, while service user passwords will be stored at `/etc/lme/vault/`


### Verification post install:
Make sure to use `-i` to run a login shell with any commands that run as root, so environment varialbes are set proprerly [LINK](https://unix.stackexchange.com/questions/228314/sudo-command-doesnt-source-root-bashrc)

1. Confirm services are installed: 
```bash
sudo systemctl  daemon-reload
sudo systemctl list-unit-files lme\*
```

Debug if necessary:
```bash
#if something breaks use this to see what goes on:
sudo -i journalctl -xu lme.service
#or sub in whatever service you want

#try resetting failed: 
sudo -i systemctl  reset-failed lme*
sudo -i systemctl  restart lme.service

#also try inspecting container logs: 
#CONTAINER_NAME=lme-elasticsearch
sudo -i podman logs -f $CONTAINER_NAME
```

2. Check conatiners are running and healthy:
```bash
sudo -i podman ps --format "{{.Names}} {{.Status}}"
```  

example output: 
```shell
lme-elasticsearch Up 2 hours (healthy)
lme-kibana Up 2 hours (healthy)
lme-wazuh-manager Up About an hour
lme-fleet-server Up 50 minutes
```
We are working on getting health check commands for wazuh and fleet, currently they are not integrated

3. Check you can connect to elasticsearch
```bash
#substitute your password below:
curl -k -u elastic:$(sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep elastic | awk '{print $1}') | tr -d '\n') https://localhost:9200
```

4. Check you can connect to kibana
You can use an ssh proxy to forward a local port to the remote linux host
```bash
#connect via ssh if you need to 
ssh -L 8080:localhost:5601 [YOUR-LINUX-SERVER]
#go to browser:
#https://localhost:8080
```

### To Uninstall: 

To uninstall everything: 
**WARNING THIS WILL DELETE EVERYTHING!!!**
``` bash
sudo -i -u root 
systemctl stop lme* && systemctl reset-failed && podman volume rm -a &&  podman secret rm -a && rm -rf /opt/lme && rm -rf /etc/lme && rm -rf /etc/containers/systemd
```

To stop/optionally uninstall things:
**WARNING THIS WILL DELETE EVERYTHING!!!**
Stop lme services: 
```bash
sudo systemctl stop lme*
sudo systemctl disable lme.service
sudo -i podman stop $(sudo -i podman ps -aq)
sudo -i podman rm $(sudo -i podman ps -aq)
```
**WARNING THIS WILL DELETE EVERYTHING!!!**

To delete only lme volumes:
```bash
sudo -i podman volume ls --format "{{.Name}}" | grep lme | xargs podman volume rm
```
or
To delete all volumes: 
```bash
sudo -i podman volume rm -a
```
**WARNING THIS WILL DELETE EVERYTHING!!!**

## Installing Sysmon on Windows Clients:

Sysmon provides valuable logs for windows computers. For each of your windows client machines, install Sysmon like so:

1. Download Logging Made Easy and unzip the folder. 
2. From inside the unzipped folder, run the following command in Administrator Powershell:
```
.\scripts\install_sysmon.ps1
```

### Other Post install setup: 
A few other things are needed and you're all set to go. 
1. setting up fleet
2. fixing a few issues with wazuh (in a future release this won't be necessary)
3. setting up custom LME dashboards
4. setting up wazuh's dashboards
5. setting up a read only user for analysts to connect and query LME's data

Luckily we've packed this in a script for you. Before running it we want to make sure our podman containers are healthy and setup. Run the command `sudo -i podman ps --format "{{.Names}} {{.Status}}"`
```bash
lme-user@ubuntu:~/LME-TEST$ sudo -i podman ps --format "{{.Names}} {{.Status}}"
lme-elasticsearch Up 49 minutes (healthy)
lme-wazuh-manager Up 48 minutes
lme-kibana Up 36 minutes (healthy)
lme-fleet-server Up 35 minutes
```

If you see something like the above you're good to go to run the command:
```
ansible-playbook ./ansible/post_install_local.yml
```

You'll see the following in the `/opt/lme/dashboards/elastic/` and `/opt/lme/dashboards/wazuh/` directories if dashboard installation was successful:
```bash

```

## Deploying Agents: 

### Deploy Wazuh Agent on client machine (Linux)

curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list

apt-get update

WAZUH_MANAGER="CHANGE ME TO DOCKER HOST IP ADDRESS" apt-get install wazuh-agent

Start the service: 

```
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

### Deploy Wazuh Agent On client Machine (Windows)

From PowerShell with admin capabilities run the following command

```
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.5-1.msi -OutFile wazuh-agent-4.7.5-1.msi;`
Start-Process msiexec.exe -ArgumentList '/i wazuh-agent-4.7.5-1.msi /q WAZUH_MANAGER="IPADDRESS OF WAZUH HOST MACHINE"' -Wait -NoNewWindow`
```

Start the service: 

```
NET START Wazuh
```


### Deploying Elastic-Agent: 
1. Run the `scripts/set-fleet.sh` file
2. follow the gui and deploy an agent on your client: https://0.0.0.0:5601/app/fleet/agents
3. Then login to kibana, go to fleet, click 'add agent' choose linux or windows depending on what endpoint. I like to perform these lines of code one at a time for testing. The final line where it actually does the install... add --insecure to the end. This is until we figure out how to do this with the certs in the cert store etc.


## Password Encryption:
Password encryption is enabled using ansible-vault to store all lme user and lme service user passwords at rest.
We do submit a hash of the password to Have I been pwned to check to see if it is compromised: [READ MORE HERE](https://haveibeenpwned.com/FAQs)

### where are passwords stored?:
```bash
# Define user-specific paths
USER_VAULT_DIR="/etc/lme/vault"
PASSWORD_FILE="/etc/lme/pass.sh"
```

### MANUALLY setting up passwords and accessing passwords **UNSUPPORTED**:
**These steps are not fully supported and are left if others would like to suppor this in their environment**

Run the password_management.sh script:
```bash
lme-user@ubuntu:~/LME-TEST$ sudo -i ${PWD}/scripts/password_management.sh -h
-i: Initialize all password environment variables and settings
-s: set_user: Set user password
-p: Manage Podman secret
-l: List Podman secrets
-h: print this list
```

### grabbing passwords: 
To view the appropriate service user password use ansible-vault, as root: 
```
#script:
$CLONE_DIRECTORY/scripts/extract_secrets.sh -p #to print

#add them as variables to your current shell
source $CLONE_DIRECTORY/scripts/extract_secrets.sh #without printing values
source $CLONE_DIRECTORY/scripts/extract_secrets.sh -q #with no output

```
#### manually getting passwords:
#where wazuh_api is the service user whose password you want:
sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep wazuh_api | awk '{print $1}')

# Documentation: 

### Logging Guidance
 - [LME in the CLOUD](/docs/markdown/logging-guidance/cloud.md)
 - [Log Retention](/docs/markdown/logging-guidance/retention.md)  *TODO*: change link to new documentation
 - [Additional Log Types](/docs/markdown/logging-guidance/other-logging.md)  

## Reference: 
 - [FAQ](/docs/markdown/reference/faq.md)  *TODO*
 - [Troubleshooting](/docs/markdown/reference/troubleshooting.md) *TODO*
 - [Dashboard Descriptions](/docs/markdown/reference/dashboard-descriptions.md)
 - [Guide to Organizational Units](/docs/markdown/chapter1/guide_to_ous.md)
 - [Security Model](/docs/markdown/reference/security-model.md)

## Maintenance:
 - [Backups](/docs/markdown/maintenance/backups.md)  *TODO* change link to new documentation
 - [Upgrading 1x -> 2x](/scripts/upgrade/README.md) 
 - [Certificates](/docs/markdown/maintenance/certificates.md) *TODO* 

## Agents: 
*TODO* add in docs in new documentation
