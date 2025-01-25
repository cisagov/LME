
[![BANNER](/docs/imgs/lme-image.png)]()

[![Downloads](https://img.shields.io/github/downloads/cisagov/lme/total.svg)]()



# Logging Made Easy 

CISA's Logging Made Easy (LME) is a no cost, open source platform that centralizes log collection, enhances threat detection, and enables real-time alerting, helping small to medium-sized organizations secure their infrastructure. Whether you're upgrading from a previous version or deploying for the first time, LME offers a scalable, efficient solution for logging and endpoint security.

## Who is Logging Made Easy for?

From single IT administrators with a handful of devices in their network to small and medium-sized agencies. Really, for anyone! 
LME is intended for organizations that:
- Need a log management and threat detection system.
- Do not have an existing Security Operations Center (SOC), Security Information and Event Management (SIEM) solution or log management and monitoring capabilities.
- Work within limited budgets, time or expertise to set up and manage a logging and threat detection system.


## Updates 

For LME's 2.0 release, we’re introducing several new features and architectural components to improve Security Information and Event Management (SIEM) capabilities while simplifying overall use of LME:

- **Enhanced Threat Detection and Response**: Integrated Wazuh’s and Elastic's open-source tools, along with ElastAlert, for improved detection accuracy and real-time alerting. 
- **Security by Design**: Introduced Podman containerization and encryption to meet the highest security standards.
- **Simplified Installation**: Added Ansible scripts to automate deployment for faster setup and easier maintenance.
- **Custom Data Visualization**: Design and customize dashboards with Kibana to meet specific monitoring needs.
- **Comprehensive Testing**: Expanded unit testing and threat emulation ensure system stability and reliability.


LME 2.0 is fully operational and built to deliver effective log management and threat detection. As part of our commitment to continuous improvement, future updates, including version 2.1, will introduce additional enhancements for scalability and deployment flexibility.

## Questions:
If you have found an issue with LME code or documentation, please submit a [GitHub issue](https://github.com/cisagov/lme/issues). For installation questions, please review all open and closed issues to see if it's addressed. If not, then submit a [GitHub issue](https://github.com/cisagov/lme/issues) using the Bug Template, ensuring that you provide all the requested information.

For general LME questions or suggestions, please visit [GitHub Discussions](https://github.com/cisagov/lme/discussions) to add a discussion post.

## Share Your Feedback:
Your input is essential to the continuous improvement of LME and to ensure it best meets your needs. Take a few moments to complete our [LME Feedback Survey](https://forms.office.com/g/TNytTeexG0). Together, we can improve LME's ability to secure your organization!


## Table of Contents:
1. [Prerequisites:](#1-prerequisites)
2. [Architecture:](#2-architecture)
3. [Downloading and Installing LME:](#3-downloading-and-installing-lme)
4. [Deploying Agents:](#4-deploying-agents)
5. [Password Encryption:](#5-password-encryption)
6. [Documentation:](#6-documentation)
7. [Uninstall (if you want to remove LME):](#7-uninstall)

## 1. Prerequisites
If you're unsure whether you meet the prerequisites for installing LME, please refer to our [prerequisites documentation](/docs/markdown/prerequisites.md).

The main prerequisite is setting up hardware for your Ubuntu server, which should have at least:

- Two (2) processors
- 16GB RAM
- 128GB of dedicated storage for LME’s Elasticsearch database.

If you need to run LME with less than 16GB of RAM or minimal hardware, please follow our troubleshooting guide to configure Podman quadlets for reduced memory usage. We recommend setting Elasticsearch to an 8GB limit and Kibana to a 4GB limit. You can find the guide [here](/docs/markdown/reference/troubleshooting.md#memory-in-containers-need-more-ramless-ram-usage).

We estimate that you should allow half an hour to complete the entire installation process. The following time table of real recorded times will provide you a reference of how long the installation may take to complete.

### Estimated Installation Times

| Milestones 				| Time 		| Timeline 	|
| ------------- 			| ------------- | ------------- |
| Download LME 				| 0:31.49 	| 0:31.49 	|
| Set Environment 			| 0:35.94 	| 1:06.61 	|
| Install Ansible 			| 1:31.94 	| 2:38.03 	|
| Installing LME Ansible Playbook 	| 4:03.63 	| 6:41.66 	|
| All Containers Active 		| 6:41.66 	| 13:08.92 	|
| Accessing Elastic 			| 0:38.97 	| 13:47.60 	|
| Post-Install Ansible Playbook 	| 2:04.34 	| 15:51.94 	|
| Deploy Linux Elastic Agent 		| 0:49.95 	| 16:41.45 	|
| Deploy Windows Elastic Agent 		| 1:32.00 	| 18:13.40 	|
| Deploy Linux Wazuh Agent 		| 1:41.99 	| 19:55.34 	|
| Deploy Windows Wazuh Agent 		| 1:55.00 	| 21:51.22 	|
| Download LME Zip on Windows 		| 2:22.43	| 24:13.65 	|
| Install Sysmon 			| 1:04.34 	| 25:17.99 	|
| Windows Integration 		 	| 0:39.93 	| 25:57.27 	|

## 2. Architecture:
LME runs on Ubuntu 22.04 and leverages Podman containers for security, performance, and scalability. We’ve integrated Wazuh,  Elastic, and ElastAlert open source tools to provide log management, endpoint security monitoring, alerting, and data visualization capabilities. This modular, flexible architecture supports efficient log storage, search, and threat detection, and enables you to scale as your logging needs evolve.

### Diagram: 

![diagram](/docs/imgs/lme-architecture-v2.png) 

### Containers:
Containerization allows each component of LME to run independently, increasing system security, improving performance, and making troubleshooting easier. 

LME uses Podman as its container engine because it is more secure (by default) against container escape attacks than other engines like Docker. It's far more debug and programmer friendly. We’re making use of Podman’s unique features, such as Quadlets (Podman's systemd integration) and User Namespacing,  to increase system security and operational efficiency.

LME uses these containers:

  - **Setup**: Runs `/config/setup/init-setup.sh` based on the configuration of DNS defined in `/config/setup/instances.yml`. The script will create a certificate authority (CA), underlying certificates for each service, and initialize the admin accounts for Elasticsearch(user:`elastic`) and Kibana(user:`kibana_system`). 
  - **Elasticsearch**: Runs LME's database and indexes all logs.
  - **Kibana**: The front end for querying logs, visualizing data, and managing fleet agents.
  - **Elastic Fleet-Server**: Executes an [elastic agent ](https://github.com/elastic/elastic-agent) in fleet-server mode. Coordinates elastic agents to  gather client logs and status. Configuration is inspired by the [elastic-container](https://github.com/peasead/elastic-container) project.
  - **Wazuh-Manager**: Allows LME to deploy and manage Wazuh agents.
    -  Wazuh (open source) gives EDR (Endpoint Detection Response) with security dashboards to cover the security of all of the machines.
  - **LME-Frontend** (*coming in a future release*): Will host an API and GUI that unifies the architecture behind one interface.
   
### Required Ports:
Ports required are as follows:
 - Elasticsearch: *9200*
 - Kibana: *443,5601*
 - Wazuh: *1514,1515,1516,55000,514*
 - Agent: *8220*

**Note**: For Kibana, 5601 is the default port. We've also set kibana to listen on 443 as well.

### Agents and Agent Management: 
LME leverages both Wazuh and Elastic agents providing more comprehensive logging and security monitoring across various log sources. The agents gather critical data from endpoints and send it back to the LME server for analysis, offering organizations deeper visibility into their security posture. We also make use of the Wazuh Manager and Elastic Fleet for agent orchestration and management.

- **Wazuh Agents**: Enables Endpoint Detection and Response (EDR) on client systems, providing advanced security features like intrusion detection and anomaly detection. For more information, see [Wazuh's agent documentation](https://github.com/wazuh/wazuh-agent). 
- **Wazuh Manager**: Responsible for managing Wazuh Agents across endpoints, and overseeing agent registration, configuration, and data collection, providing centralized control for monitoring security events and analyzing data. 
- **Elastic Agents**: Enhance log collection and management, allowing for greater control and customization in how data is collected and analyzed. Agents also feature a vast collection of integrations for many log types/applications. For more information, see [Elastic's agent documentation](https://github.com/elastic/elastic-agent).
- **Elastic Fleet**: Manages Elastic Agents across your infrastructure, providing centralized control over agent deployment, configuration, and monitoring. It simplifies the process of adding and managing agents on various endpoints. ElasticFleet also supports centralized updates and policy management.


### Alerting:
LME has setup [ElastAlert](https://elastalert2.readthedocs.io/en/latest/index.html), an open-source alerting framework, to automate alerting based on data stored in Elasticsearch. It monitors Elasticsearch for specific patterns, thresholds, or anomalies, and generates alerts when predefined conditions are met. This provides proactive detection of potential security incidents, enabling faster response and investigation. ElastAlert’s flexible rule system allows for custom alerts tailored to your organization’s security monitoring needs, making it a critical component of the LME alerting framework. 

### Log Storage and Search:

As the core component for log search and storage, [Elasticsearch](https://www.elastic.co/elasticsearch) indexes and stores logs and detections collected from Elastic and Wazuh Agents, allowing for fast, real-time querying of security events. Elasticsearch enables users to search and filter large datasets efficiently, providing a powerful backend for data analysis and visualization in Kibana. Its scalability and flexibility make it essential for handling the high-volume log data generated across different endpoints within LME's architecture.

### Data Visualization and Querying:
[Kibana](https://www.elastic.co/kibana) is the visualization and analytics interface in LME, providing users with tools to visualize and monitor log data stored in Elasticsearch. It enables the creation of custom dashboards and visualizations, allowing users to easily track security events, detect anomalies, and analyze trends. Kibana's intuitive interface supports real-time insights into the security posture of an organization, making it an essential tool for data-driven decision-making in LME’s centralized logging and security monitoring framework.

## 3. Downloading and Installing LME:
LME now includes Ansible scripts to automate the installation process, making deployment faster and more efficient. Our installation guide video is coming soon. When the video is released, you will find the link to it here. 
These steps will guide you through setting up LME on your Ubuntu 22.04 server, ensuring a smooth and secure deployment.

**Note:** LME has been extensively tested on Ubuntu 22.04. While it can run on other Unix-like systems, we recommend sticking with Ubuntu 22.04 for the best experience.

**Please ensure you follow all the configuration steps required below.**

**Upgrading**:
If you are upgrading from an older version of LME to LME 2.0, please see our [upgrade documentation](/docs/markdown/maintenance/upgrading.md).

### Downloading LME:
The following steps assume you're starting from a downloaded or cloned directory of LME on your Ubuntu 22.04 server.

We suggest you install the latest release version of LME using the following commands: 

**1. Install Requirements**
```
sudo apt update && sudo apt install curl jq unzip -y
```
**2. Download and Unzip the latest version of LME**
This will add a path to ~/LME with all required files.
```
curl -s https://api.github.com/repos/cisagov/LME/releases/latest | jq -r '.assets[0].browser_download_url' | xargs -I {} sh -c 'curl -L -O {} && unzip -d ~/LME $(basename {})'
```
Developer Note: if you're looking to develop LME, its suggested you `git clone` rather than downloading, please see our [DEV docs](#developer-notes)

### Configuration
The configuration files are located in /config/. These steps will guide you through setting up LME

**1. Certificates and Passwords**
- instances.yml defines the certificates to be created.
- Shell scripts will initialize accounts and generate certificates. They run from the quadlet definitions lme-setup-accts and lme-setup-certs.
  
**2. Podman Quadlet Configuration**
- Quadlet configuration for containers is located in /quadlet/. These map to the root systemd unit files but execute as non-privileged users.

**3. Environment Variables**
- Only edit the /config/lme-environment.env file to set required environment variables.

\***USER REQUIRED EDITS**:\*
The only file users needs to touch is creating `/config/lme-environment.env`, which sets up the required environment variables.

This should be the IP address that your agents will use to connect to this server.

Get your IP address via the following command: 
```
hostname -I | awk '{print $1}'
```

Setup the config via the following  steps:
```
#change directory to ~/LME or whatever your download directory is above
cd ~/LME 
cp ./config/example.env ./config/lme-environment.env
```
In the new `lme-environment.env` file, update the following values:
```
#your host ip as found from the above command
IPVAR=127.0.0.1 #your hosts ip 
```

### **Automated Install**

You can run this Ansible installer for a fully automated install. 

```bash
sudo apt update && sudo apt install -y ansible
# cd ~/LME/lme-2-arch # Or path to your clone of this repo
ansible-playbook ./ansible/install_lme_local.yml
```
This assumes that you have the repo in `~/LME/`. 

If you don't, you can pass the `CLONE_DIRECTORY` variable to the playbook. 
```bash
ansible-playbook ./ansible/install_lme_local.yml -e "clone_dir=/path/to/clone/directory" 
```
**If you have issues accessing a file or directory, please note permissions and notes on folder structure [here](#notes-on-folders-permissions-and-service)**

This also assumes your user can sudo without a password. If you need to input a password when you sudo, you can run it with the `-K` flag and it will prompt you for a password. 
```bash
ansible-playbook -K ./ansible/install_lme_local.yml -e "clone_dir=/path/to/clone/directory" 
```
In the `BECOME password` prompt enter the password for your user you would normally give `sudo`, so the playbook is able to sudo as expected.

#### Steps performed in automated install: 

1. Setup /opt/lme and check for sudo access. Configure other required directories/files.
2. **Setup password information**: Configures the password vault and other configuration for the service user passwords.  
3. **Setup [Nix](https://nixos.org/)**: nix is the open source package manager we use to install the latest version of podman.
4. **Set service user passwords**: Sets the service user passwords that are encrypted according to the [security model](/docs/markdown/reference/security-model.md).
5. **Install Quadlets**: Installs quadlet files in the directories described below to be setup as systemd services.
6. **Setup Containers for root**: The containers listed in `$clone_directory/config/containers.txt` will be pulled and tagged.
7. **Start lme.service**: Kicks off the start of LME service containers.

**Notes on folders, permissions, and service:**
1. `/opt/lme` will be owned by root, all LME services will run and execute as unprivileged users. The active LME configuration is stored in `/opt/lme/config`. 
     To access any file at `/opt/lme/` you'll need to make sure you're in a root shell (e.g. `sudo -i su`) or you run whatever command you're wanting to access in that directory as root (e.g. `sudo ls /opt/lme/config`)
 
2. Other relevant directories are listed here: 
- `/root/.config/containers/containers.conf`: LME will setup a custom podman configuration for secrets management via [ansible vault](https://docs.ansible.com/ansible/latest/cli/ansible-vault.html).
- `/etc/lme`: storage directory for the master password and user password vault
- `/etc/lme/pass.sh`: the master password file
- `/etc/containers/systemd`: directory where LME installs its quadlet service files
- `/etc/systemd/system`: directory where lme.service is installed
 
3. The master password will be stored at `/etc/lme/pass.sh` and owned by root, while service user passwords will be stored at `/etc/lme/vault/`

4. lme.service is a KICK START systemd service. It will always succeed and is designed so that the other lme services can be stopped and restarted by stopping/restarting lme.service.

For example, to stop all of LME: 
```bash
sudo -i systemctl stop lme.service
```

To restart all of LME: 
```bash
sudo -i systemctl restart lme.service
```

To start all of LME:
```bash
sudo -i systemctl start lme.service
```


### Verification Post-Install:
Make sure to use `-i` to run a login shell with any commands that run as root, so environment variables are set properly [LINK](https://unix.stackexchange.com/questions/228314/sudo-command-doesnt-source-root-bashrc)

**The services take a while to start give it a few minutes before assuming things are broken**

1. Confirm services are installed: 
```bash
sudo systemctl daemon-reload
sudo systemctl list-unit-files lme\*
```

Debug if necessary. The first step is to check the status of individual services listed above:
```bash
#if something breaks, use these commands to debug:
SERVICE_NAME=lme-elasticsearch.service
sudo -i journalctl -xu $SERVICE_NAME
```

If something is broken, try restarting the services and making sure failed services reset before starting:
```bash
#try resetting failed: 
sudo -i systemctl  reset-failed lme*
sudo -i systemctl  restart lme.service
```

2. Check that containers are running and healthy. This command will also print container names!
```bash
sudo -i podman ps --format "{{.Names}} {{.Status}}"
```  

Example output: 
```shell
lme-elasticsearch Up 19 hours (healthy)
lme-wazuh-manager Up 19 hours
lme-kibana Up 19 hours (healthy)
lme-fleet-server Up 19 hours
lme-elastalert2 Up 17 hours
```
This also prints the names of the containers in the first column of text on the left. You'll want the container names.

We are currently missing health checks for fleet-server and elastalert2, so if those are up they won't show healthy and thats expected. Health checks for these services will be added in a future version.

If a container is missing you can check its logs here: 
```bash
#also try inspecting container logs: 
CONTAINER_NAME=lme-elasticsearch #change this to your container name you want to monitor lme-kibana, etc...
sudo -i podman logs -f $CONTAINER_NAME
```

3. Check if you can connect to Elasticsearch
```bash
#substitute your password below:
curl -k -u elastic:$(sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep elastic | awk '{print $1}') | tr -d '\n') https://localhost:9200
```

Example output:
```json
{
  "name" : "lme-elasticsearch",
  "cluster_name" : "LME",
  "cluster_uuid" : "FOnfbFSWQZ-PD-rU-9w4Mg",
  "version" : {
    "number" : "8.12.2",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "48a287ab9497e852de30327444b0809e55d46466",
    "build_date" : "2024-02-19T10:04:32.774273190Z",
    "build_snapshot" : false,
    "lucene_version" : "9.9.2",
    "minimum_wire_compatibility_version" : "7.17.0",
    "minimum_index_compatibility_version" : "7.0.0"
  },
  "tagline" : "You Know, for Search"
}

```

4. Check if you can connect to Kibana <br/>
You can use a ssh proxy to forward a local port to the remote linux host. To login as the Elastic admin use the username `elastic` and elastics password grabbed from the export password script [here](#grabbing-passwords)
```bash
#connect via ssh if you need to 
ssh -L 8080:localhost:5601 [YOUR-LINUX-SERVER]
#go to browser:
#https://localhost:8080
```

You can also navigate to your browser at the value you set for `IPVAR`: https://IPVAR


### Other Post-Install Setup: 
A few other things are needed and you're all set to go. 
1. Setting up Elasticfleet
2. Fixing a few issues with Wazuh (in a future release this won't be necessary)
3. Setting up custom LME dashboards
4. Setting up Wazuh's dashboards
5. Setting up a read only user for analysts to connect and query LME's data

Luckily we've packed this in a script for you. Before running it we want to make sure our Podman containers are healthy and setup. Run the command `sudo -i podman ps --format "{{.Names}} {{.Status}}"`
```bash
lme-user@ubuntu:~/LME-TEST$ sudo -i podman ps --format "{{.Names}} {{.Status}}"
lme-elasticsearch Up 49 minutes (healthy)
lme-wazuh-manager Up 48 minutes
lme-kibana Up 36 minutes (healthy)
lme-fleet-server Up 35 minutes
```

If you see something like above you're good to go to run the command. 
The services need to be running when you execute this playbook, it makes api calls to the Kibana, Elasticfleet, and Wazuh services.
As before, this script needs to be run from 
```
CLONE_DIRECTORY=~/LME #or whatever directory you cloned it to
cd $CLONE_DIRECTORY
ansible-playbook ./ansible/post_install_local.yml
```

**IMPORTANT**: The post-install script will setup the password for a `readonly_user` to use with analysts that want to query/hunt in Elasticsearch, but doesn't need access to administrator functionality.
The end of the script will output the password of the read only user... be sure to save that somewhere.

Here's an example where the password is `oz9vLny0fB3HA8S2hH!FLZ06TvpaCq`. Every time this script is run that password for the readonly user will be changed, so be careful to make sure you only run this when you need to, ideally one time.
```bash
TASK [DISPLAY NEW READONLY USER PASSWORD] ***************************************************************************************************************************************
ok: [localhost] => {
    "msg": "LOGIN WITH readonly_user via:\n USER: readonlyuser\nPassword: oz9vLny0fB3HA8S2hH!FLZ06TvpaCq"
    }
    
    PLAY RECAP **********************************************************************************************************************************************************************
    localhost                  : ok=27   changed=6    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
    
```

#### Verify Post-Install: 

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

## 4. Deploying Agents: 
We have separate guides on deploying Wazuh and Elastic in separate docs, please see links below:
Eventually, LME will automate these steps in a future release. 

 - [Deploy Wazuh Agent](/docs/markdown/agents/wazuh-agent-mangement.md)
 - [Deploying Elastic-Agent](/docs/markdown/agents/elastic-agent-mangement.md)

### Installing Sysmon on Windows Clients:

Sysmon provides valuable logs for windows computers. For each of your windows client machines, install Sysmon like so:

1. Download LME and unzip the folder. 
2. From inside the unzipped folder, run the following command in Administrator Powershell:
```
.\scripts\install_sysmon.ps1
```

To run this powershell script, you may need to temporarily set the powershell script execution policy to "Unrestricted" which lets Windows execute downloaded powershell scripts. You can do that with the following command:
```
Set-ExecutionPolicy Unrestricted
```

## 5. Password Encryption:
Ansible-vault is used to enable password encryption, securely storing all LME user and service user passwords at rest
We do submit a hash of the password to Have I Been Pwned to check to see if it is compromised: [READ MORE HERE](https://haveibeenpwned.com/FAQs), but since they're all randomly generated this should be rare.

### Where Are Passwords Stored?:
```bash
# Define user-specific paths
USER_VAULT_DIR="/etc/lme/vault"
PASSWORD_FILE="/etc/lme/pass.sh"
```

### Grabbing Passwords: 
To view the appropriate service user password run the following commands:
```
#script:
$CLONE_DIRECTORY/scripts/extract_secrets.sh -p #to print

#add them as variables to your current shell
source $CLONE_DIRECTORY/scripts/extract_secrets.sh #without printing values
source $CLONE_DIRECTORY/scripts/extract_secrets.sh -q #with no output
```

### Manually Setting Up Passwords and Accessing Passwords **Unsupported**:
**These steps are not fully supported by CISA and are left if others would like to support this in their environment**

Run the password_management.sh script:
```bash
lme-user@ubuntu:~/LME-TEST$ sudo -i ${PWD}/scripts/password_management.sh -h
-i: Initialize all password environment variables and settings
-s: set_user: Set user password
-p: Manage Podman secret
-l: List Podman secrets
-h: print this list
```

A cli one liner to grab passwords (this also demonstrates how we're using Ansible-vault in extract_secrets.sh):
```bash
#where wazuh_api is the service user whose password you want:
USER_NAME=wazuh_api
sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep $USER_NAME | awk '{print $1}')
```

# 6. Documentation: 

## Logging Guidance
 - [LME in the Cloud](/docs/markdown/logging-guidance/cloud.md)
 - [Log Retention](/docs/markdown/logging-guidance/retention.md)
 - [Filtering](/docs/markdown/logging-guidance/filtering.md)

## Reference: 
 - [FAQ](/docs/markdown/reference/faq.md) 
 - [Dashboard Descriptions](/docs/markdown/reference/dashboard-descriptions.md)
 - [Security Model](/docs/markdown/reference/security-model.md)

## Maintenance:
 - [Alerting](/docs/markdown/maintenance/elastalert-rules.md)
 - [Backups](/docs/markdown/maintenance/backups.md)  
 - [Certificates](/docs/markdown/maintenance/certificates.md) 
 - [Encryption at Rest](/docs/markdown/maintenance/Encryption_at_rest_option_for_users.md)
 - Data management:
   - [Index Management](/docs/markdown/maintenance/index-management.md)
   - [Volume Management](/docs/markdown/maintenance/volume-management.md)
 - Upgrading:
   - [Upgrading 1x -> 2x](/scripts/upgrade/README.md) 
   - [Upgrading Future 2.x](/docs/markdown/maintenance/upgrading.md)

## Agents: 
Here is documentation on agent configuration and management.
 - [Elastic-Agent](/docs/markdown/agents/elastic-agent-mangement.md)
 - Wazuh:
   - [Wazuh Configuration](/docs/markdown/maintenance/wazuh-configuration.md)
   - [Active Response](/docs/markdown/agents/wazuh-active-response.md)
   - [Agent Management](/docs/markdown/agents/wazuh-agent-mangement.md)
    
## Endpoint Tools:
To make best use of the agents, complement them with utilities that generate forensically relevant data to analyze and support detections.
Consider adding them to Windows/Linux.

### Windows:
 - [Sysmon (manual install)](/docs/markdown/endpoint-tools/install-sysmon.md)
### Linux:
 - [Auditd](/docs/markdown/endpoint-tools/install-auditd.md)

# 7. Uninstall
This walks through how to completely uninstall LME's services and data. 

The dependencies will not be removed this way, if desired we can add that to the documentation, and you can consult the ansible scripts to see what was installed, and remove the created directories.
 
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

Once you've gotten your changes/updates added, please submit a pull request following our  [guidelines](/CONTRIBUTING.md)

