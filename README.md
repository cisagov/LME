
![N|Solid](/docs/imgs/cisa.png)

[![Downloads](https://img.shields.io/github/downloads/cisagov/lme/total.svg)]()

# Logging Made Easy: Podmanized

This will eventually be merged with the Readme file at [LME-README](https://github.com/cisagov/LME). 

## TLDR: 
LME will now execute its server stack via systemd through quadlet's.   
All the original compose functionality has been implemented and working.   

## Architecture:
Ubuntu 22.04 server running podman containers setup as podman quadlets controlled via systemd.

### Required Ports:
Ports required are as follows:
 - Elasticsearch: *9200*
 - Caddy: *443*
 - Wazuh: *1514,1515,55000,514*
 - Agent: *8220*


### Diagram: 
**TODO** update the link below before merge to main  

![diagram](https://github.com/cisagov/LME/blob/release-2.0.0/docs/imgs/lme-architecture-v2.jpg)

### why podman?:
Podman is more secure (by default) against container escape attacks than Docker. It also is far more debug and programmer friendly for making containers secure. 

### Containers:
  - caddy: acts as a reverse proxy for the container architecture:
    - routes traffic to the backend services
    - hosts lme-front end
    - helps access all services behind one pane of glass
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

### Operating system: **Ubuntu 22.04**:
Important: Change appropriate variables in `$CLONE_DIRECTORY/example.env`  Each variable is documented inside `example.env`. You'll want to change the default passwords!

After changing those variables, you can run the automated install, or do a manual install. 

### Configuration

Configuration is `/config/`
 in `setup` find the configuration for certificate generation and password setting. `instances.yml` defines the certificates that will get created.  The shellscripts initialize accounts and create certificates, and will run from their respective quadlet definitions `lme-setup-accts` and `lme-setup-certs` respectively.
 in `caddy` is the Caddyfile for the reverse proxy. Find more notes on its syntax and configuraiton here: [CADDY DOCS](https://caddyserver.com/docs/caddyfile)
 
Quadlet configuration for containers is in: `/quadlet/`. These are mapped to the root's systemd unit files, but will execute as the `lmed` user.

\***TO EDIT**:\*
The only file that really needs to be touched is creating `/config/lme-environment.env`, which sets up the required environment variables
To do this follow these steps:
```
cp /config/example.env /config/lme-environment.env
#update the following values:
IPVAR=127.0.0.1 #your hosts ip 
```

### **Automated Install**

You can run this installer to run the total install in ansible. 

```bash
sudo apt update && sudo apt install -y ansible
# cd ~/LME-PRIV/lme-2-arch # Or path to your clone of this repo
ansible-playbook install_lme_local.yml
```
This assumes that you have the repo in `~/LME/`. 

If you don't, you can pass the `CLONE_DIRECTORY` variable to the playbook. 
```
ansible-playbook ./scripts/install_lme_local.yml -e "clone_dir=/path/to/clone/directory" 
```

This also assumes your user can sudo without a password. If you need to input a password when you sudo, you can run it with the `-K` flag and it will prompt you for a password. 

#### Steps performed in automated install: 
1. Creates `/opt/lme` to store the state of LME configuraiton, and copies quadlets to `/etc/containers/`

2. Logs for lme will be available via podman, systemd, or `/var/log/lme` *TODO: add a logging directory for LME*

#### NOTES:

1. `/opt/lme` will be owned by the lmed user, all lme services will run and execute as lmed, and this ensures least privilege in lmed's execution because lmed is a non-admin,unprivileged user.
 
3. [this script](/scripts/set_sysctl_limits.sh) is executed via ansible AND  will change unprivileged ports to start at 80, to allow caddy to listen on 443 from a user run container. If this is not desired, we will be publishing steps to setup firewall rules using ufw//iptables to manage the firewall on this host at a later time. 

4. the master password will be stored at `/etc/lme/pass.sh` and owned by root, all containers will execute as the `lmed` user.


### After install:

Confirm setup: 
```
sudo systemctl  daemon-reload
sudo systemctl list-unit-files lme\*
```

1. Copy the file `example.env` to the running environment file:
```bash
cp $CLONE_DIRECTORY/example.env /opt/lme/lme-environment.env
```
    
3. Change appropriate variables in `/opt/lme/lme-environment.env` Each variable is documented inside `example.env`. You'll want to change the default passwords!

## Run: 

### pull and tag all containers:
This will let us maintain the lme container versions using the `LME_LATEST` tag. Whenever we update, we change the local image to point to the newest update, and run `podman auto-update` to update the containers. 

**NOTE TO FUTURE SELVES: NEEDS TO BE `LOCALHOST` TO AVOID REMOTE TAGGING ATTACK**

```bash
sudo mkdir -p /etc/containers
sudo tee /etc/containers/policy.json <<EOF
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
EOF
```

```bash
#1:
# cat $CLONE_DIRECTORY/config/containers.txt | xargs -n1 -P8 podman pull -q
xargs -a $CLONE_DIRECTORY/config/containers.txt -I {} sh -c 'echo "Pulling {}..."; podman pull {} && echo "Successfully pulled {}" || echo "Failed to pull {}"'
#2:
for x in $(cat $CLONE_DIRECTORY/config/containers.txt  | tr '\n' ' ');do short=$(echo $x | awk -F/ '{print $3}'| awk -F: '{print $1}'); if [ "$short" == "" ];then short="caddy";fi;  podman image tag $x ${short}:LME_LATEST; done
```

### Start all the services
```bash
systemctl --user daemon-reload
systemctl --user start lme.service
```

### verify running: 

Check systemctl:
```bash
systemctl --user list-unit-files lme\*

#if something breaks use this to see what goes on:
journalctl --user -u lme.service
#or sub in whatever service you want

#try resetting failed: 
systemctl --user reset-failed
```

Check you can connect to elasticsearch
```bash
#substitute your password below:
curl -k -u elastic:password1 https://localhost:9200
```

Check conatiners are running:
```bash
podman ps --format "{{.Names}} {{.Status}}"
```  

example output: 
```shell
lme-elasticsearch Up 2 hours (healthy)
lme-kibana Up 2 hours
lme-wazuh-manager Up About an hour
lme-fleet-server Up 50 minutes
lme-caddy Up 14 minutes
```

Check you can connect to kibana
```bash
#connect via ssh
ssh -L 8080:localhost:443 [YOUR-LINUX-SERVER]
#go to browser:
#https://localhost:8080
```

### stop service: 
```
systemctl --user stop lme-*.service
```

### delete all data: 
WARNING THIS WILL DELETE EVERYTHING!!!
```bash
WARNING THIS WILL DELETE EVERYTHING!!!
podman volume ls --format "{{.Name}}" | grep lme | xargs podman volume rm
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
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.5-1.msi -OutFile wazuh-agent-4.7.5-1.msi; Start-Process msiexec.exe -ArgumentList '/i wazuh-agent-4.7.5-1.msi /q WAZUH_MANAGER="IPADDRESS OF WAZUH HOST MACHINE"' -Wait -NoNewWindow
```

Start the service: 

```
NET START Wazuh
```


### Deploying Elastic-Agent: 
1. Run the `scripts/set-fleet.sh` file
2. follow the gui and deploy an agent on your client: https://0.0.0.0:5601/app/fleet/agents

## Password Encryption:
Password encryption is enabled using ansible-vault to store all lme user and lme service user passwords at rest.
We do submit a hash of the password to Have I been pwned to check to see if it is compromised: [READ MORE HERE](https://haveibeenpwned.com/FAQs)


### where are passwords stored?:
```
# Define user-specific paths
USER_CONFIG_DIR="$HOME/.config/lme"
USER_VAULT_DIR="$HOME/.local/share/lme/vault"
USER_SECRETS_CONF="$USER_CONFIG_DIR/secrets.conf"
```

###  `password_management.sh`:
TODO

# Documentation: 

### Installation:
 - [Prerequisites - Start deployment here](/docs/markdown/prerequisites.md)  
 - [Chapter 1 - Set up Windows Event Forwarding](/docs/markdown/chapter1/chapter1.md)  
 - [Chapter 2 – Sysmon Install](/docs/markdown/chapter2.md)  
 - [Chapter 3 – Database Install](/docs/markdown/chapter3/chapter3.md)  
 - [Chapter 4 - Post Install Actions ](/docs/markdown/chapter4.md)  

### Logging Guidance
 - [Log Retention](/docs/markdown/logging-guidance/retention.md)  
 - [Additional Log Types](/docs/markdown/logging-guidance/other-logging.md)  

### Reference:
 - [FAQ](/docs/markdown/reference/faq.md)  
 - [Troubleshooting](/docs/markdown/reference/troubleshooting.md)
 - [Dashboard Descriptions](/docs/markdown/reference/dashboard-descriptions.md)
 - [Guide to Organizational Units](/docs/markdown/chapter1/guide_to_ous.md)
 - [Security Model](/docs/markdown/reference/security-model.md)

### Maintenance:
 - [Backups](/docs/markdown/maintenance/backups.md)  
 - [Upgrading](/docs/markdown/maintenance/upgrading.md)  
 - [Certificates](/docs/markdown/maintenance/certificates.md)  
 
# Dev notes:
Notes to convert compose -> quadlet
1. start the containers with compose
2. podlet generate from the containers created

### compose:
running:  
```shell
podman-compose up -d
```

stopping:  
```shell
podman-compose down --remove-orphans

#only run if you want to remove all volumes:
podman-compose down -v --remove-orphans
```

### install/get podlet: 
```
#https://github.com/containers/podlet/releases
wget https://github.com/containers/podlet/releases/download/v0.3.0/podlet-x86_64-unknown-linux-gnu.tar.xz
#add it to path:
cp ./podlet-x86_64-unknown-linux-gnu/podlet  .local/bin/
```

### generate the quadlet files:
[DOCS](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html), [BLOG](https://mo8it.com/blog/quadlet/)  

```
cd ~/LME-PRIV/quadlet

for x in $(podman ps --filter label=io.podman.compose.project=lme-2-arch -a  --format "{{.Names}}");do echo $x; podlet generate container $x > $x.container;done
```

### dealing with journalctl logs: 
https://unix.stackexchange.com/questions/638432/clear-failed-states-or-all-old-logs-from-systemctl-status-service
```
#delete all logs:
sudo rm /var/log/journal/$STRING_OF_HEX/user-1000*
```

### debugging commands:
```
systemctl --user stop lme.service
systemctl --user status lme*
systemctl --user restart lme.service
journalctl --user -u lme-fleet-server.service
systemctl --user status lme*
cp -r $CLONE_DIRECTORY/config/ /opt/lme && cp -r $CLONE_DIRECTORY/quadlet /opt/lme
systemctl --user daemon-reload && systemctl --user list-unit-files lme\*
systemctl --user reset-failed
podman volume rm -a

###make sure all ports are free as well: 
sudo ss -tulpn
```

### password setup stuff:
#### setup the config directory
This will setup the container config so it uses ansible vault for podman secret creation AND sets up the proper ansible-vault environment variables.

```
ln -sf /opt/lme/config/containers.conf $HOME/.config/containers/containers.conf
#preserve `chmod +x` executable
cp -rTp config/ /opt/lme/config
#source our password env var: 
. ./scripts/set_vault_key_env.sh
#create the vault directory:
/opt/lme/vault/
```

#### create password file: 
This will setup the ansible vault files in the expected paths
```
ansible-vault create /opt/lme/vault.yml
```

### **Manual Install OLD**( optional if not running ansible install):
```
export CLONE_DIRECTORY=~/LME-PRIV/lme-2-arch
#systemd will setup nix:
#Old way to setup nix if desired: sh <(curl -L https://nixos.org/nix/install) --daemon
sudo apt install jq uidmap nix-bin nix-setup-systemd  

sudo nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
sudo nix-channel --update

# Add user to nix group in /etc/group
sudo usermod -aG nix-users $USER

#install podman and podman-compose
sudo nix-env -iA nixpkgs.podman 

# Set the path for root and lme-user
#echo 'export PATH=$PATH:$HOME/.nix-profile/bin' >> ~/.bashrc
echo 'export PATH=$PATH:/nix/var/nix/profiles/default/bin' >> ~/.bashrc
sudo sh -c 'echo "export PATH=$PATH:/nix/var/nix/profiles/default/bin" >> /root/.bashrc'

#to allow 443/80 bind and setup memory/limits
sudo NON_ROOT_USER=$USER $CLONE_DIRECTORY/set_sysctl_limits.sh

#export XDG_CONFIG_HOME="$HOME/.config"
#export XDG_RUNTIME_DIR=/run/user/$(id -u)

#setup user-generator on systemd:
sudo $CLONE_DIRECTORY/link_latest_podman_quadlet.sh

#setup loginctl
sudo loginctl enable-linger $USER
```

Quadlet configuration for containers is in: `/quadlet/`
1. setup `/opt/lme` thats the running directory for lme: 
```bash
sudo mkdir -p /opt/lme
sudo chown -R $USER:$USER /opt/lme
cp -r $CLONE_DIRECTORY/config/ /opt/lme/
cp -r $CLONE_DIRECTORY/quadlet/ /opt/lme/

#setup quadlets
mkdir -p ~/.config/containers/
ln -s /opt/lme/quadlet ~/.config/containers/systemd

#setup service file
mkdir -p ~/.config/systemd/user
ln -s /opt/lme/quadlet/lme.service ~/.config/systemd/user/
```
