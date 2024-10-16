
![N|Solid](/docs/imgs/cisa.png)

[![Downloads](https://img.shields.io/github/downloads/cisagov/lme/total.svg)]()

# Logging Made Easy: Podmanized

This will eventually be merged with the Readme file at [LME-README](https://github.com/cisagov/LME). 

## Table of Contents:
-   [Architecture:](#architecture)
-   [Installation:](#installation)
-   [Deploying Agents:](#deploying-agents)
-   [Password Encryption:](#password-encryption)
-   [Further Documentation:](#documentation)

## Architecture:
Ubuntu 22.04 server running podman containers setup as podman quadlets controlled via systemd.

### Required Ports:
Ports required are as follows:
 - Elasticsearch: *9200*
 - Kibana: 443,5601 
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
  - lme-frontend: will host an api and gui that unifies the architecture behind one interface

### Agents: 
Wazuh agents will enable EDR capabilities, while Elastic agents will enable logging capabilities.

 - https://github.com/wazuh/wazuh-agent   
 - https://github.com/elastic/elastic-agent  

## Installation:

If you are unsure you meet the pre-requisites to installing LME, please read our [prerequisites documentation](/docs/markdown/prerequisites.md)
Please ensure you follow all the configuration steps required below.


### Downloading LME:
**All steps will assume you start in your cloned directory of LME on your ubuntu 22.04 server**

We suggest you install the latest release version of Logging made easy using the following commands: 
```
sudo apt update && sudo apt install curl jq unzip -y

curl -s https://api.github.com/repos/cisagov/LME/releases/latest | jq -r '.assets[0].browser_download_url' | xargs -I {} sh -c 'curl -L -O {} && unzip -d ~/LME $(basename {})"'
```

### Operating system: **Ubuntu 22.04**:
Make sure you run an install on ubuntu 22.04, thats the operating system which has been tested the most. 
In theory, you can install LME on any nix... but we've only tested and run installs on 22.04.

### Configuration

Configuration is `/config/`
in `setup` find the configuration for certificate generation and password setting.  
`instances.yml` defines the certificates that will get created.    
The shellscripts initialize accounts and create certificates, and will run from their respective quadlet definitions `lme-setup-accts` and `lme-setup-certs` respectively.
 
Quadlet configuration for containers is in: `/quadlet/`. These are mapped to the root's systemd unit files, but will execute as the `lmed` user.

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

### OPTIONAL: setting master password
This password will be used to encrypt all service user passwords and you should make sure to keep track of it (it will also be stored in `/etc/lme/pass.sh`).
```
sudo -i ${PWD}/scripts/password_management.sh -i
```
You can skip this step if you would like to have the script setup the master password for you and you'll never need to touch it :)


### **Automated Install**

You can run this installer to run the total install in ansible. 

```bash
sudo apt update && sudo apt install -y ansible
# cd ~/LME-PRIV/lme-2-arch # Or path to your clone of this repo
ansible-playbook ./scripts/install_lme_local.yml
```
This assumes that you have the repo in `~/LME/`. 

If you don't, you can pass the `CLONE_DIRECTORY` variable to the playbook. 
```
ansible-playbook ./scripts/install_lme_local.yml -e "clone_dir=/path/to/clone/directory" 
```

This also assumes your user can sudo without a password. If you need to input a password when you sudo, you can run it with the `-K` flag and it will prompt you for a password. 

#### Steps performed in automated install: 
TODO finalize this with more words 

1. Setup /opt/lme, check sudo, and configure other required directories/files
2. Setup password information
3. Setup Nix
4. set service user passwords
5. Install Quadlets
6. Setup Containers for root
7. Start lme.service

#### NOTES:

1. `/opt/lme` will be owned by the lmed user, all lme services will run and execute as lmed, and this ensures least privilege in lmed's execution because lmed is a non-admin,unprivileged user.
 
2. the master password will be stored at `/etc/lme/pass.sh` and owned by root, while service user passwords will be stored at `/etc/lme/vault/`


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
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.5-1.msi -OutFile wazuh-agent-4.7.5-1.msi; Start-Process msiexec.exe -ArgumentList '/i wazuh-agent-4.7.5-1.msi /q WAZUH_MANAGER="IPADDRESS OF WAZUH HOST MACHINE"' -Wait -NoNewWindow
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
USER_CONFIG_DIR="/root/.config/lme"
USER_VAULT_DIR="/opt/lme/vault"
USER_SECRETS_CONF="$USER_CONFIG_DIR/secrets.conf"
PASSWORD_FILE="/etc/lme/pass.sh"
```

### MANUALLY setting up passwords and accessing passwords:
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
#where wazuh_api is the service user whose password you want:
sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep wazuh_api | awk '{print $1}')
```



# Documentation: 

### Logging Guidance
 - [LME in the CLOUD](/docs/markdown/logging-guidance/cloud.md)
 - [Log Retention](/docs/markdown/logging-guidance/retention.md)  TODO update to be current
 - [Additional Log Types](/docs/markdown/logging-guidance/other-logging.md)  

### Reference: TODO update these to current
 - [FAQ](/docs/markdown/reference/faq.md)  
 - [Troubleshooting](/docs/markdown/reference/troubleshooting.md)
 - [Dashboard Descriptions](/docs/markdown/reference/dashboard-descriptions.md)
 - [Guide to Organizational Units](/docs/markdown/chapter1/guide_to_ous.md)
 - [Security Model](/docs/markdown/reference/security-model.md)
 - [DEV NOTES](/docs/markdown/reference/dev-notes)

### Maintenance:
 - [Backups](/docs/markdown/maintenance/backups.md)  
 - [Upgrading](/docs/markdown/maintenance/upgrading.md)  
 - [Certificates](/docs/markdown/maintenance/certificates.md)  
 
