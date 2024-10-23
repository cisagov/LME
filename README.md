
[![BANNER](/docs/imgs/REPLACEME)]()

[![Downloads](https://img.shields.io/github/downloads/cisagov/lme/total.svg)]()



# Logging Made Easy: 

Logging Made Easy (LME) is a free, open-source platform developed by CISA to centralize log collection, enhance threat detection, and enable real-time alerting, helping organizations of all sizes secure their infrastructure. LME offers a seamless user experience, integrating Wazuh and Elastic tools to improve detection accuracy and enable endpoint security. 

Whether you're upgrading from a previous version or deploying for the first time, LME offers a scalable, efficient solution for logging and endpoint security with a range of advanced features:

- Enhanced Threat Detection and Response: Integrates Wazuh’s open-source tools and Elastic Fleet for improved detection accuracy and faster response times.
- Security by Design: Utilizes containerization and encryption to meet the highest security standards.
- Simplified Installation: Ansible scripts automate deployment for faster setup and easier maintenance.
- Custom Data Visualization: Create personalized dashboards for tailored monitoring.
- Comprehensive Testing: Expanded unit testing and threat emulation ensure system stability and reliability.


## Updates: 

With our LME 2.0 release, we’re introducing several new features and architectural components:
  - LME now provides organizations with SIEM capabilities to enhance event management, threat detection, and alerting.
  - The LME team simplified the installation process and created clear instructions on what to download and which configurations to use.
  - Ansible scripts to automate the install and also provide detailed steps for users that want to manually install.

LME 2.0 is still in development, and version 2.1 will address scaling out the deployment.

## Questions or Feedback:
The LME team is not able to comment on or troubleshoot individual installations. If you believe you have found an issue with the LME code or documentation, please submit a GitHub issue. If you have a question about your installation, please look through all open and closed issues to see if it has been addressed before. If not, then submit a [GitHub issue](https://github.com/cisagov/lme/issues) using the Bug Template, ensuring that you provide all the requested information.

For general questions about LME and suggestions, please visit [GitHub Discussions](https://github.com/cisagov/lme/discussions) to add a discussion post.

## Who is Logging Made Easy for?

From single IT administrators with a handful of devices in their network to larger organizations.

LME is suited for for:

- Organizations without Security OPerations Center ([SOC](https://en.wikipedia.org/wiki/Information_security_operations_center)), Security Information and Event Management (SIEM), or any monitoring in place at the moment.
- Organizations that lack the budget, time or understanding to set up a logging system.
- Organizations that that require gathering logs and monitoring IT

## Table of Contents:
-   [Pre-Requisites:](#architecture)
-   [Architecture:](#architecture)
-   [Installation:](#installing-lme)
-   [Deploying Agents:](#deploying-agents)
-   [Password Encryption:](#password-encryption)
-   [Further Documentation & Upgrading:](#documentation)
-   [Uninstall (if desired):](#uninstall)

## Pre-Requisites
If you are unsure you meet the pre-requisites to installing LME, please read our [prerequisites documentation](/docs/markdown/prerequisites.md).
The biggest Pre-requisite is setting up hardware for your ubuntu server with a minimum of `2 processors`, `16gb ram`, and `128gb` of dedicated storage for LME's Elasticsearch database.

If you really want to try to run with less than 16gb ram or at a minimum amount of hardware  you can follow the troubleshooting guide to setup the podman quadlets to run with a limited amount of ram. We suggest setting elasticsearch to a limit of `8gb` and kibana to a limit of `4gb`. See the guide [here](/docs/markdown/reference/troubleshooting.md#memory-in-containers-need-more-ramless-ram-usage)

## Architecture:
LME runs on Ubuntu 22.04 and leverages Podman containers for security, performance, and scalability. We’ve integrated Wazuh’s Manager and Agent with Elastic to provide comprehensive log collection, endpoint security monitoring, alerting, and data visualization capabilities. This modular, flexible architecture supports efficient log storage, search, and threat detection, and will enable seamless scaling to meet your organization’s evolving security and logging requirements.


### Diagram: 

![diagram](/docs/imgs/lme-architecture-v2.jpg)

### why Podman?:
We chose Podman as LME’s container engine because it is more secure (by default) against container escape attacks than other engines like Docker. It also is far more debug and programmer friendly. We’re making use of Podman’s unique features, such as Quadlets (Podman's systemd integration) and User Namespacing,  to increase system security and operational efficiency. 

### Containers:
Containerization allows each component of LME to run independently, increasing system security, improving performance, and making troubleshooting easier. Below are the containers we’re using for LME:

  - **Setup**: runs `/config/setup/init-setup.sh` based on the configuration of DNS defined in `/config/setup/instances.yml`. The script will create a CA, underlying certs for each service, and intialize the admin accounts for elasticsearch(user:`elastic`) and kibana(user:`kibana_system`). 
  - **Elasticsearch**: runs the database for LME and indexes all logs.
  - **Kibana**: the front end for querying logs,  investigating via dashboards, and managing fleet agents.
  - **Elastic Fleet-Server**: [executes](executes) a [elastic agent ](https://github.com/elastic/elastic-agent) in fleet-server mode. It coordinates elastic agents to  gather logs and status from clients. Configuration is inspired by the [elastic-container](https://github.com/peasead/elastic-container) project.
    - Elastic agents provide integrations, have more features than winlogbeat.
  - **Wazuh-Manager**: runs the wazuh manager so we can deploy and manage wazuh agents.
    -  Wazuh (open source) gives EDR (Endpoint Detection Response) with security dashboards to cover the security of all of the machines.
  - **LME-Frontend** (*coming in a future release*): will host an api and gui that unifies the architecture behind one interface
   
### Required Ports:
Ports required are as follows:
 - Elasticsearch: *9200*
 - Kibana: *443,5601*
 - Wazuh: *1514,1515,1516,55000,514*
 - Agent: *8220*

**Kibana NOTE**: 5601 is the default port, and we've set kibana to listen on 443 as well

### Agents and Agent Management: 
LME leverages both Wazuh and Elastic agents providing more comprehensive logging and security monitoring across various log sources. The agents gather critical data from endpoints and send it back to the LME server for analysis, offering organizations deeper visibility into their security posture. We also make use of the Wazuh Manager and Elastic Fleet for agent orchestration and management.

- **Wazuh Agents**: Enables Endpoint Detection and Response (EDR) on client systems, providing advanced security features like intrusion detection and anomaly detection. https://github.com/wazuh/wazuh-agent 
- **Wazuh Manager**: Responsible for managing Wazuh Agents across endpoints, and overseeing agent registration, configuration, and data collection, providing centralized control for monitoring security events and analyzing data. 
- **Elastic Agents**: Enhance log collection and management, allowing for greater control and customization in how data is collected and analyzed. Agents also feature a vast collection of integrations for many log types/applications https://github.com/elastic/elastic-agent
- **Elastic Fleet**: Responsible for managing Elastic Agents across your infrastructure, providing centralized control over agent deployment, configuration, and monitoring. It simplifies the process of adding and managing agents on various endpoints. ElasticFleet also supports centralized updates and policy management.


### Alerting:
LME has setup [ElastAlert](https://elastalert2.readthedocs.io/en/latest/index.html), an open-source alerting framework, to automate alerting based on data stored in Elasticsearch. It monitors Elasticsearch for specific patterns, thresholds, or anomalies, and generates alerts when predefined conditions are met. This provides proactive detection of potential security incidents, enabling faster response and investigation. ElastAlert’s flexible rule system allows for custom alerts tailored to your organization’s security monitoring needs, making it a critical component of the LME alerting framework. 

### Log Storage and Search:

[Elasticsearch](https://www.elastic.co/elasticsearch) is the core component for log storage and search in LME. It indexes and stores logs and detections collected from Elastic and Wazuh Agents, allowing for fast, real-time querying of security events. Elasticsearch enables users to search and filter large datasets efficiently, providing a powerful backend for data analysis and visualization in Kibana. Its scalability and flexibility make it essential for handling the high-volume log data generated across different endpoints within LME's architecture.

### Data Visualization and Querying:
[Kibana](https://www.elastic.co/kibana) is the visualization and analytics interface in LME, providing users with tools to visualize and monitor log data stored in Elasticsearch. It enables the creation of custom dashboards and visualizations, allowing users to easily track security events, detect anomalies, and analyze trends. Kibana's intuitive interface supports real-time insights into the security posture of an organization, making it an essential tool for data-driven decision-making in LME’s centralized logging and security monitoring framework.

## Installing LME:
LME now includes Ansible scripts to automate the installation process, making deployment faster and more efficient. You can follow our [installation video](TODO LINK HERE) for further guidance.
These steps will guide you through setting up LME on your Ubuntu 22.04 server, ensuring a smooth and secure deployment.

**Please ensure you follow all the configuration steps required below.**

#####**Upgrading**:
If you are a previous user of LME and wish to upgrade from 1.4 -> 2.0, please see our [upgrade documentation](/docs/markdown/maintenance/upgrading.md).


### Downloading LME:
**All steps will assume you start the downloaded or cloned directory of LME on your Ubuntu 22.04 server**

We suggest you install the latest release version of Logging made easy using the following commands: 

Install Requirements
```
sudo apt update && sudo apt install curl jq unzip -y
```
Download and Unzip the latest version of LME. This will add a path to ~/LME with all requires files.
```
curl -s https://api.github.com/repos/cisagov/LME/releases/latest | jq -r '.assets[0].browser_download_url' | xargs -I {} sh -c 'curl -L -O {} && unzip -d ~/LME $(basename {})'
```
***Developer Note: if you're looking to develop LME, its suggested you `git clone` rather than downloading, please see our [DEV docs](#developer-notes)***

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

1. Setup /opt/lme, check for sudo access, and configure other required directories/files
2. Setup password information: configures the password vault and other configuration for the service user passwords  
3. Setup [Nix](https://nixos.org/): nix is the opensource package manager we use to install the latest version of podman
4. set service user passwords: actually sets the service user passwords that are encrypted according to the [security model](/docs/markdown/reference/security-model.md)
5. Install Quadlets: the quadlet files are setup in the directories described below to be setup as systemd services
6. Setup Containers for root: The contianers listed in `$clone_directory/config/containers.txt` will be pulled and tagged
7. Start lme.service: kicks of the start of LME service containers

#### NOTES:

1. `/opt/lme` will be owned by root, all lme services will run and execute as unprivileged users. The active lme configuration is stored in `/opt/lme/config`.
 
2. Other relevant directories are listed here: 
- `/root/.config/containers/containers.conf`: LME will setup a custom podman configuration for secrets management via [ansible vault](https://docs.ansible.com/ansible/latest/cli/ansible-vault.html).
- `/etc/lme`: storage directory for the master password and user password vault
- `/etc/lme/pass.sh`: the master password file
- `/etc/containers/systemd`: directory where LME installs its quadlet service files
- `/etc/systemd/system`: directory where lme.service is installed
 
3. the master password will be stored at `/etc/lme/pass.sh` and owned by root, while service user passwords will be stored at `/etc/lme/vault/`

4. lme.service is a KICK START systemd service. It will always succeed and is designed so that the other lme services can be stopped and restarted by stopping/restarting lme.service.
For example, to stop all of lme: 
```bash
sudo -i systemctl stop lme.service
```

To restart all of lme: 
```bash
sudo -i systemctl restart lme.service
```

To start all of lme:
```bash
sudo -i systemctl start lme.service
```


### Verification post install:
Make sure to use `-i` to run a login shell with any commands that run as root, so environment varialbes are set proprerly [LINK](https://unix.stackexchange.com/questions/228314/sudo-command-doesnt-source-root-bashrc)

1. Confirm services are installed: 
```bash
sudo systemctl  daemon-reload
sudo systemctl list-unit-files lme\*
```

Debug if necessary. The first step is to check the status of individual services listed above:
```bash
#if something breaks use this to see what goes on:
SERVICE_NAME=lme-elasticsearch.service
sudo -i journalctl -xu $SERVICE_NAME
```

If somehting is broken try restarting the services and making sure failed services reset before starting:
```bash
#try resetting failed: 
sudo -i systemctl  reset-failed lme*
sudo -i systemctl  restart lme.service
```

2. Check conatiners are running and healthy. this is also how to print out the container names!
```bash
sudo -i podman ps --format "{{.Names}} {{.Status}}"
```  

example output: 
```shell
lme-elasticsearch Up 19 hours (healthy)
lme-wazuh-manager Up 19 hours
lme-kibana Up 19 hours (healthy)
lme-fleet-server Up 19 hours
lme-elastalert2 Up 17 hours
```
This also prints the names of the containers in the first column of text on the left. You'll want the container names

If a container is missing you can check its logs here: 
```bash
#also try inspecting container logs: 
$CONTAINER_NAME=lme-elasticsearch #change this to your container name you want to monitor lme-kibana, etc...
sudo -i podman logs -f $CONTAINER_NAME
```

3. Check you can connect to elasticsearch
```bash
#substitute your password below:
curl -k -u elastic:$(sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep elastic | awk '{print $1}') | tr -d '\n') https://localhost:9200
```

4. Check you can connect to kibana
You can use an ssh proxy to forward a local port to the remote linux host. To login as the elastic admin use the username `elastic` and elastics password grabbed from the export password script [here](#grabbing-passwords)
```bash
#connect via ssh if you need to 
ssh -L 8080:localhost:5601 [YOUR-LINUX-SERVER]
#go to browser:
#https://localhost:8080
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

If you see something like the above you're good to go to run the command. The services need to be running when you execute this playbook, it makes api calls to the kibana, fleet, and wazuh services.
```
ansible-playbook ./ansible/post_install_local.yml
```

**IMPORTANT**: the post install script will setup the password for a `readonly_user` to use with analysts that want to query/hunt in elasticsearch, but don't need access to administrator functionality.
The end of the script will output the password of hte read only user... be sure to save that somewhere.

Heres an example where the password is `oz9vLny0fB3HA8S2hH!FLZ06TvpaCq`. Every time this script is run that password for the readonly user will be changed, so be careful to make sure you only run this when you need to, ideally one time.
```bash
TASK [DISPLAY NEW READONLY USER PASSWORD] ***************************************************************************************************************************************
ok: [localhost] => {
    "msg": "LOGIN WITH readonly_user via:\n USER: readonlyuser\nPassword: oz9vLny0fB3HA8S2hH!FLZ06TvpaCq"
    }
    
    PLAY RECAP **********************************************************************************************************************************************************************
    localhost                  : ok=27   changed=6    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
    
```

#### Verify post install: 

Run the following commands to check `/opt/lme/dashboards/elastic/` and `/opt/lme/dashboards/wazuh/` directories if dashboard installation was successful:
```bash
sudo -i 
ls -al /opt/lme/FLEET_SETUP_FINISHED
ls -al /opt/lme/dashboards/elastic/INSTALLED
ls -al /opt/lme/dashboards/wazuh/INSTALLED
```

which should look like the following: 
```bash
root@ubuntu:~# ls -al /opt/lme/FLEET_SETUP_FINISHED
-rw-r--r-- 1 root root 0 Oct 21 18:41 /opt/lme/FLEET_SETUP_FINISHED
root@ubuntu:~# ls -al /opt/lme/dashboards/elastic/INSTALLED
-rw-r--r-- 1 root root 0 Oct 21 18:44 /opt/lme/dashboards/elastic/INSTALLED
root@ubuntu:~# ls -al /opt/lme/dashboards/wazuh/INSTALLED
-rw-r--r-- 1 root root 0 Oct 21 19:01 /opt/lme/dashboards/wazuh/INSTALLED
```

## Deploying Agents: 
We have seperate guides on deploying Wazuh and Elastic in seperate docs, please see links below:
Eventually these steps will be more automated in a future release. 

##### - [Deploy Wazuh Agent](/docs/markdown/agents/wazuh-agent-mangement.md)
##### - [Deploying Elastic-Agent](/docs/markdown/agents/elastic-agent-mangement.md)

## Password Encryption:
Password encryption is enabled using ansible-vault to store all lme user and lme service user passwords at rest.
We do submit a hash of the password to Have I been pwned to check to see if it is compromised: [READ MORE HERE](https://haveibeenpwned.com/FAQs), but since they're all randomly generated this should be RARE.

### where are passwords stored?:
```bash
# Define user-specific paths
USER_VAULT_DIR="/etc/lme/vault"
PASSWORD_FILE="/etc/lme/pass.sh"
```

### grabbing passwords: 
To view the appropriate service user password run the following commands:
```
#script:
$CLONE_DIRECTORY/scripts/extract_secrets.sh -p #to print

#add them as variables to your current shell
source $CLONE_DIRECTORY/scripts/extract_secrets.sh #without printing values
source $CLONE_DIRECTORY/scripts/extract_secrets.sh -q #with no output
```

#### manually getting passwords:
```bash
#where wazuh_api is the service user whose password you want:
USER_NAME=wazuh_api
sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep $USER_NAME | awk '{print $1}')
```

### MANUALLY setting up passwords and accessing passwords **UNSUPPORTED**:
**These steps are not fully supported and are left if others would like to support this in their environment**

Run the password_management.sh script:
```bash
lme-user@ubuntu:~/LME-TEST$ sudo -i ${PWD}/scripts/password_management.sh -h
-i: Initialize all password environment variables and settings
-s: set_user: Set user password
-p: Manage Podman secret
-l: List Podman secrets
-h: print this list
```

# Documentation: 

## Logging Guidance
 - [LME in the CLOUD](/docs/markdown/logging-guidance/cloud.md)
 - [Log Retention](/docs/markdown/logging-guidance/retention.md)
 - [Filtering](/docs/markdown/logging-guidance/filtering.md)

## Reference: 
 - [FAQ](/docs/markdown/reference/faq.md) 
 - [Troubleshooting](/docs/markdown/reference/troubleshooting.md)
 - [Dashboard Descriptions](/docs/markdown/reference/dashboard-descriptions.md) *TODO*: update with new 2.0 dashboard descriptions
 - [Security Model](/docs/markdown/reference/security-model.md)

## Maintenance:
 - [Backups](/docs/markdown/maintenance/backups.md)  *TODO:* update with new directions for how to backup
 - [Certificates](/docs/markdown/maintenance/certificates.md) 
 - [Encryption at rest](/docs/markdown/maintenance/Encryption at rest option for users.md)
 - Data management:
   - [Index Management](/docs/markdown/maintenance/index-management.md)
   - [Volume Management](/docs/markdown/maintenance/volume-management.md)
 - Upgrading:
   - [Upgrading 1x -> 2x](/scripts/upgrade/README.md) 
   - [Upgrading future 2.X](/docs/markdown/maintenance/upgrading.md)

## Agents: 
This is documentatino on agent configuration and management
 - [Elastic-Agent](/docs/markdown/agents/elastic-agent-mangement.md)
 - Wazuh:
   - [Wazuh Configuration](/docs/markdown/maintenance/wazuh-configuration.md)
   - [Active Response](/docs/markdown/agents/wazuh-active-response.md)
   - [Agent Management](/docs/markdown/agents/wazuh-agent-mangement.md)
    
## endpoint tools:
In order to make best use of the agents, they need to be complemented by utilities to generate forensically relevant data to analyze and support detections.
Look at adding them to Windows/Linux

### Windows:
 - [Sysmon](/docs/markdown/endpoint-tools/install-sysmon.md)
### Linux:
 - [Sysmon](/docs/markdown/endpoint-tools/install-auditd.md)

# Uninstall
 
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
 
# Developer notes:
 
Git clone and git checkout your development branch on the server:
```bash
git clone https://github.com/cisagov/LME.git
cd LME
git checkout YOUR_BRANCH_NAME_HERE
```

