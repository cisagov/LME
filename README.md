
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
1. [What is LME?:](#1-what-is-lme?)
2. [Prerequisites:](#1-prerequisites)
3. [Downloading and Installing LME:](#2-downloading-and-installing-lme)
4. [Whats Next?:](#3-whats-next?)
5. [Documentation:](#4-documentation)
5. [Developer Notes](#5-developer-notes)


## 1. What is LME?: 
For more precise understanding of LME's architecture please see our [architecture documentation](/docs/markdown/reference/architecture.md).

### Description:
LME runs on Ubuntu 22.04 and leverages Podman containers for security, performance, and scalability. We’ve integrated Wazuh,  Elastic, and ElastAlert open source tools to provide log management, endpoint security monitoring, alerting, and data visualization capabilities. This modular, flexible architecture supports efficient log storage, search, and threat detection, and enables you to scale as your logging needs evolve.

### How does LME work?:

![diagram](/docs/imgs/lme-architecture-v2.png) 

Important pieces to understand from an LME user perspective:

1. **Collecting**: Logs are collected via  agents  
  - **Wazuh Agents**: Enables Endpoint Detection and Response (EDR) on client systems, providing advanced security features like intrusion detection and anomaly detection. For more information, see [Wazuh's agent documentation](https://github.com/wazuh/wazuh-agent). 
  - **Elastic Agents**: Enhance log collection and management, allowing for greater control and customization in how data is collected and analyzed. Agents also feature a vast collection of integrations for many log types/applications. For more information, see [Elastic's agent documentation](https://github.com/elastic/elastic-agent).
2. **Viewing**: Logs are viewable in dashboards via kibana  
  - [Kibana](https://www.elastic.co/kibana) is the visualization and analytics interface in LME, providing users with tools to visualize and monitor log data stored in Elasticsearch. It enables the creation of custom dashboards and visualizations, allowing users to easily track security events, detect anomalies, and analyze trends. Kibana's intuitive interface supports real-time insights into the security posture of an organization, making it an essential tool for data-driven decision-making in LME’s centralized logging and security monitoring framework.

3. **Alerting**: Creating notifications for logs organizations want to  configurable via Elastalert:
  -  [ElastAlert](https://elastalert2.readthedocs.io/en/latest/index.html) is an open-source alerting framework, to automate alerting based on data stored in Elasticsearch. It monitors Elasticsearch for specific patterns, thresholds, or anomalies, and generates alerts when predefined conditions are met. This provides proactive detection of potential security incidents, enabling faster response and investigation. ElastAlert’s flexible rule system allows for custom alerts tailored to your organization’s security monitoring needs, making it a critical component of the LME alerting framework. 
 
### What firewall rules do I need to setup?:
Please see our doucmentation around cloud and firewall setup for more information on how you can [expose these ports](/docs/markdown/logging-guidance/cloud.md)
Ports that need to be open at the server where LME is installed are listed below:
 - Elasticsearch: *9200*
 - Kibana: *443,5601*
 - Wazuh: *1514,1515,1516,55000,514*
 - Agent: *8220*

**Note**: For Kibana, 5601 is the default port. We've also set kibana to listen on 443 as well.


## 2. Prerequisites
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

## 3. Downloading and Installing LME:
LME now includes Ansible scripts to automate the installation process, making deployment faster and more efficient. Our installation guide video is coming soon. When the video is released, you will find the link to it here.

These steps will guide you through setting up LME on your Ubuntu 22.04 server, ensuring a smooth and secure deployment.

**Note:** LME has been extensively tested on Ubuntu 22.04. While it can run on other Unix-like systems, we recommend sticking with Ubuntu 22.04 for the best experience.

**Please ensure you follow all the configuration steps required below.**

**Upgrading**:
If you are upgrading from an older version of LME to LME 2.0, please see our [upgrade documentation](/docs/markdown/maintenance/upgrading.md).

### 1. Downloading LME:
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

### 2. Configuration

The configuration files are located in `~/LME/config/`. These steps will guide you through setting up LME.

Get your IP address via the following command. This IP should be the IP address clients will forward logs to, and should be reachable from all clients you would like to log from.
```
hostname -I | awk '{print $1}'
```

Setup the environment with your new ip address via the following  steps:
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

### 3. Installation
This assumes that you have the repo in `~/LME/`. If you have deviated from our instructions, jump to our [notes on non-default installation](#non-default-installation-notes)
```bash
sudo apt update && sudo apt install -y ansible
# cd ~/LME/lme-2-arch # Or path to your clone of this repo
ansible-playbook ./ansible/install_lme_local.yml
```

**----The services can take a while to start give it a few minutes before assuming things are broken----**

Check that containers are running and healthy. This command will also print container names!
```bash
sudo -i podman ps --format "{{.Names}} {{.Status}}"
```  

You should see output like this, if you don't please attempt these [troubleshooting steps](/docs/markdown/reference/troubleshooting.md#installation-troubleshooting)
```shell
lme-elasticsearch Up 19 hours (healthy)
lme-wazuh-manager Up 19 hours
lme-kibana Up 19 hours (healthy)
lme-fleet-server Up 19 hours
lme-elastalert2 Up 17 hours
```

Proceed to Post-Installation steps.

### 4. Post installation steps:

If you encounter any issues, try running through our post-installation [troubleshooting steps](/docs/markdown/reference/troubleshooting.md#post-installation-troubleshooting)

```bash
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

### 5. Deploying Agents: 
Now that LME is installed, to actually get data in dashboards we have to install agents. 

We have guides on deploying Wazuh and Elastic in separate docs, please see links below (Eventually, LME will automate these steps in a future release): 

 - [Deploy Wazuh Agent](/docs/markdown/agents/wazuh-agent-mangement.md)
 - [Deploying Elastic-Agent](/docs/markdown/agents/elastic-agent-mangement.md)

### 6. (ONLY FOR WINDOWS CLIENTS) Installing Sysmon:

On windows, to get the best logs from the client (and get proper data in our dashboards), you'll need to install sysmon.  

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

## 3. Whats next?:
See some common questions below and check out our [documentation](#4-documentation) for further notes:

### Grabbing Passwords: 
To view the appropriate service user password run the following commands:
```
$CLONE_DIRECTORY/scripts/extract_secrets.sh -p
```
If you'd like more documentation around passwords see [here](/docs/markdown/reference/passwords.md)

### Starting/Stopping LME:

To stop all of LME: 
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

### Uninstall
This walks through how to completely uninstall LME's services and data. 

The dependencies will not be removed this way, if desired we can add that to the documentation, and you can consult the ansible scripts to see what was installed, and remove the created directories.
 
To uninstall everything:  
**WARNING THIS WILL DELETE EVERYTHING!!!**  
``` bash
sudo -i -u root 
systemctl stop lme* && systemctl reset-failed && podman volume rm -a &&  podman secret rm -a && rm -rf /opt/lme && rm -rf /etc/lme && rm -rf /etc/containers/systemd
#reset podman, DON'T RUN THIS IF YOU HAVE OTHER PODMAN CONTAINERS!
sudo -i podman system reset --forc
```
**WARNING THIS WILL DELETE EVERYTHING!!!**  

#### To stop/optionally uninstall things:
1. Stop lme services: 
```bash
sudo systemctl stop lme*
sudo systemctl disable lme.service
sudo -i podman stop $(sudo -i podman ps -aq)
sudo -i podman rm $(sudo -i podman ps -aq)
```

2. To delete only lme volumes:
```bash
sudo -i podman volume ls --format "{{.Name}}" | grep lme | xargs podman volume rm
```
or
To delete all volumes: 
```bash
sudo -i podman volume rm -a
```
 
 
 
### Customizing LME: 
We're doing our best to have regular updates that add new and/or requested features. A few ideas for customizing your installation to your needs. Please see the appropriate section of our documentation for more information on each topic.

1. [Alerting](/docs/markdown/maintenance/elastalert-rules.md): Adding custom notifications for triggered alerts using elastalert2
2. [Active Response](/docs/markdown/agents/wazuh-active-response.md): Creating custom wazuh active response actions to automatically respond to a malicious event wazuh detects. 
   - 
3. [Backups](/docs/markdown/maintenance/backups.md): Customizing backups of logs for your organizations own compliance needs.
4. [Custom log types](/docs/markdown/agents/elastic-agent-mangement.md#lme-elastic-agent-integration-example): using elastic agents built in [integrations](https://www.elastic.co/guide/en/integrations/current/index.html) ingest a log type specific to your organization.
  - 
# 4. Documentation:

## Logging Guidance
 - [LME in the Cloud](/docs/markdown/logging-guidance/cloud.md)
 - [Log Retention](/docs/markdown/logging-guidance/retention.md)
 - [Filtering](/docs/markdown/logging-guidance/filtering.md)

## Reference: 
 - [FAQ](/docs/markdown/reference/faq.md) 
 - [Dashboard Descriptions](/docs/markdown/reference/dashboard-descriptions.md)
 - [Security Model](/docs/markdown/reference/security-model.md)
 - [Architecture](/docs/markdown/reference/architecture.md)
 - [Configuration Customization Options](/docs/markdown/reference/configuration.md)
 - [Password Maintenance](/docs/markdown/reference/passwords.md)

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

# 5. Developer notes:
Git clone and git checkout your development branch on the server:

```bash
git clone https://github.com/cisagov/LME.git
cd LME
git checkout YOUR_BRANCH_NAME_HERE
```

Once you've gotten your changes/updates added, please submit a pull request following our  [guidelines](/CONTRIBUTING.md)

## non-default installation notes:

If you installed LME in a custom directory, you can pass the `CLONE_DIRECTORY` variable to the playbook. 
```bash
ansible-playbook ./ansible/install_lme_local.yml -e "clone_dir=/path/to/clone/directory" 
```
**If you have issues accessing a file or directory, please note permissions and notes on folder structure [here](#notes-on-folders-permissions-and-service)**

This also assumes your user can sudo without a password. If you need to input a password when you sudo, you can run it with the `-K` flag and it will prompt you for a password. 
```bash
ansible-playbook -K ./ansible/install_lme_local.yml -e "clone_dir=/path/to/clone/directory" 
```
In the `BECOME password` prompt enter the password for your user you would normally give `sudo`, so the playbook is able to sudo as expected.

## Installation details:
Below we've documented in more detail what exactly occurs during the installation and post-installation ansible scripts.

### Steps performed in automated install: 

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

