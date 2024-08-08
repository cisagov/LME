# Chapter 3 – Installing the ELK Stack and Retrieving Logs

## Chapter Overview
In this chapter you will:
* Install a new Linux server for events to be sent to.
* Run a script to:
    * install Docker.
    * secure the Linux server.
    * secure the Elasticsearch server.
    * generate certificates.
    * deploy the LME Docker stack.
* Configure the Windows Event Collector to send logs to the Linux server.

## Introduction
This section covers the installation and configuration of the Database and search functionality on a Linux server. We will install the ‘ELK’ Stack from Elasticsearch for this portion.

What is the ELK Stack?
"ELK" is the acronym for three open projects which come at no cost to users: Elasticsearch, Logstash, and Kibana. Elasticsearch is a search and analytics engine. Logstash is a server‑side data processing pipeline that ingests data from multiple sources simultaneously, transforms it, and then sends it to a "stash" like Elasticsearch. Kibana lets users visualize data with charts and graphs in Elasticsearch.

![Elkstack components](/docs/imgs/elkstack.jpg)
<p align="center">
Figure 1: Elastic Stack components
</p>

Elasticsearch, Logstash, Kibana, and Winlogbeat are developed by [Elastic](https://www.elastic.co/). Before following this guide and running our install script, you should review and ensure that you agree with the license terms associated with these products. Elastic’s license terms can be found on their GitHub page [here](https://github.com/elastic). By running our install script you are agreeing to Elastic’s terms.

This script also makes use of use of Docker Community Edition (CE). By following this guide and using our install script you are agreeing to the Docker CE license, which can be found [here](https://github.com/docker/docker-ce/blob/master/LICENSE).

## 3.1 Getting Started
During the installation guide below you will see that the majority of steps are carried out automatically. Commands or file paths are highlighted in grey boxes.

You will need a Linux box for this portion, **The deploy script is only tested on Ubuntu Long Term Support (LTS) editions that are currently supported by Docker ([see here](https://docs.docker.com/engine/install/ubuntu/)).** In addition, only installation on a single server is supported. Please see [the resilience documentation](/docs/markdown/chapter3/resilience.md) for more details.

### 3.1.1 Firewall Rules
You will need port 5044 open for the event collector to send data into the database (on the Linux server). To be able to access the web interface you will need to have firewall rules in place to allow access to port 443 (HTTPS) on the Linux server.

### 3.1.2 Web Proxy Settings
If the ELK stack is being deployed behind a web proxy and Docker isn't configured to use the proxy, the deploy script can hang without completing due to Docker being unable to pull the required images.

**If your setup does not include a web proxy, skip straight to step 3.2.**

Otherwise, to configure Docker to use the web proxy in your environment, do the following before running the deployment script:

1. Determine the IP address and port of the proxy.
2. Create a systemd drop-in directory for the Docker service:
```
sudo mkdir -p /etc/systemd/system/docker.service.d
```
3. Create a file named /etc/systemd/system/docker.service.d/http-proxy.conf that adds the HTTP_PROXY and HTTPS_PROXY environment variables (keep/delete as required for your environment, substituting the IP address/port determined in step 1):
```
[Service]
Environment="HTTP_PROXY=http://[proxy address or IP]:[proxy port]"
Environment="HTTPS_PROXY=https://[proxy address or IP]:[proxy port]"
```
4. Reload the service daemon:
```
sudo systemctl daemon-reload
```

Check the [official Docker documentation](https://docs.docker.com/config/daemon/systemd/#httphttps-proxy) for this process, including details on how to bypass the proxy if you have internal image registries which need to be reachable from this host.

## 3.2 Install LME the easy way using our script

### 3.2.1 Preparing to Run the Script

At the time of writing, security updates are only supported for Ubuntu, so please install Ubuntu on a new virtual or physical machine. You may have already done this as part of the pre-requisites in the initial readme file.

You will also need the IP address and domain name of the Linux server to run the install script.

To find the IP address, run `ip addr` from the Linux server and look for the IP address after the indicator `inet`. The IP address needs to be reachable from the event collector. See [What firewall rules are needed?](/docs/markdown/prerequisites.md#what-firewall-rules-are-needed) for more details.

The domain name needs to be resolvable from the event collector. If you're unsure what the server's domain name is, in some cases, it may just be the hostname of local machine, which you can find by running `hostname` from the Linux server. To verify if this is resolvable from the event collector, open PowerShell on the event collector and run `Resolve-DnsName MYDOMAINNAME`, where "MYDOMAINNAME" refers to the domain name of the Linux server. If successful, it will return the IP address of the Linux server. If not, an error such as "DNS name does not exist" error will be returned. In this case, you may need to add a DNS record on the domain controller that points to the Linux server. See [Manage DNS resource records](https://learn.microsoft.com/en-us/windows-server/networking/dns/manage-resource-records?tabs=powershell) to learn more about doing this.

### 3.2.2 Running the Script

**The script will prompt for the following:** 

1. Confirmation of intrusive actions that will modify your system docker and apt installed files.
2. Asking for input of the IP address of the local machine. It should automatically populate it with the server's correct local IP address on your network. If not, fill in the IP you found in [Section 3.2.1](#321-preparing-to-run-the-script).
3. Asking for input of the Fully-qualified Domain Name (aka `hostname`) of the local machine (the ELK server). Type in the ELK server's domain name you determined in [Section 3.2.1](#321-preparing-to-run-the-script).
4. Presenting the option of automatically generating self-signed TLS certificates or importing pre-generated certificates. By default self-signed certificates will be used, which will have a validity of two years from the date of install, after which they will need to be renewed.
5. Skipping the Docker installation process. This is available for the case that you already have docker installed.
6. An old elastic user password. If you are installing on top of a previous LME installation, you will need to provide your old LME elastic user password, so the install can properly authenticate with your previous systems.

Now that you have an Ubuntu machine ready to go as well as its local IP address and hostname, SSH into your Linux server and run the following commands to install LME:

```
# Install Git client to be able to clone the LME repository
sudo apt update
sudo apt install git -y
# Download a copy of the LME files
sudo git clone https://github.com/cisagov/lme.git /opt/lme/
# Change to the LME directory containing files for the Linux server
cd /opt/lme/Chapter\ 3\ Files/
# Execute script with root privileges
sudo ./deploy.sh install
```

Running the above commands will:  

1. Enable auto security updates (Ubuntu Only)
2. Update the system
  - Note that the script may request a reboot after running initial updates, especially if it's a new system or one that has not been updated for a long time. Reboot the system and run the script again to continue. 
3. Generate TLS certificates. (Optional)
4. Install Docker Community Edition.
  - Note that this action is destructive and assumes docker is not installed. Either indicate in the prompt you wish to skip installing docker **OR** uninstall docker before proceeding
5. Configure Docker to run ELK.
6. Change Elasticsearch configuration, including retention based upon disk size.
7. update read/write permission recursively on `/opt/lme` so that only the owner can read the files in that directory. This ensures only root can read the files that get created/written during deploy.sh. If you created that directory as root you will have permission errors. Access the directory using a root shell OR change the permissions for the `/opt/lme` directory so that a regular user can read it if you desire.


For details on how to regenerate these certificates, or for instructions in generating and importing certificates from an existing root Certificate Authority (CA) please see the full [certificates documentation](/docs/markdown/maintenance/certificates.md).

After the script finishes running, it will output a number of usernames and passwords for use when accessing the dashboard and for the internal systems.

The usernames and passwords will be provided in a message similar to below.

```
##################################################################################
## Kibana/Elasticsearch Credentials are (these will not be accessible again!!!!) ##
##
## Web Interface login:
## elastic:<PASSWORD>
##
## System Credentials
## kibana:<PASSWORD>
## logstash_system:<PASSWORD>
## logstash_writer:<PASSWORD>
## dashboard_update:<PASSWORD>
##################################################################################
```
**It is important that these are safely stored. Access to these passwords would allow an attacker to erase the logs. They will also not be accessible again, so store them immediately.**

### 3.2.3 Updating Log Retention Policy

The amount of logs that are retained in Logstash is calculated in the deploy script based upon 80% of the machine's disk size. The calculated size will be displayed as an output of the script.

If you wish to update log retention time, refer to the [Retention doc](/docs/markdown/logging-guidance/retention.md) after you have completely installed LME.

**Note:** The software starts deleting events based upon whichever retention criteria is met first.

### 3.2.4 Download Files for Windows Event Collector

The deploy.sh script has created files on the Linux server that need to be copied across and used on the Windows Event Collector server. The files have been zipped for convenience, with the filename and location ``` /opt/lme/files_for_windows.zip ```.

There are many ways you can copy files to and from Linux servers. Three of them are detailed below.

#### Method 1: WinSCP
You can use the WinSCP application (found [here](https://winscp.net/eng/download.php)) for a nice graphical interface to download the files. Enter your Linux server's IP address in the Host name field and your username and password. Click "Login", and then navigate to `/opt/lme` to find `files_for_windows.zip`.

![WinSCP Login Prompt](/docs/imgs/winscp.jpg)
<p align="center">
Figure 4: WinSCP Login Prompt
</p>

  - If you have a keyfile instead of a password (for example, when accessing AWS servers), see [this article](https://docs.aws.amazon.com/transfer/latest/userguide/getting-started-use-the-service.html).

#### Method 2: Windows Native SCP
SFTP and SCP have been bundled in Windows since 2018 and will suffice if you're comfortable with a command line. To download the files from the ELK server to your desktop, run the following in a powershell window on the Event Collector, filling in `<USERNAME>` with your Linux username and `<SERVER-IP>` with the IP address of the Linux server:

```
scp <USERNAME>@<SERVER-IP>:/opt/lme/files_for_windows.zip $env:UserProfile\Desktop
```

The command will ask for a password to connect. Enter your password and press enter to authenticate. *Don't worry if you don't see anything appear as you type; this is by design to keep your password hidden!*

`files_for_windows.zip` should then be downloaded to your desktop.

#### Method 3: Web Server
You can also download the file over a Python HTTP server, included on Linux by default. On the Linux server, running the below commands will copy the zip file into your home directory, and host an HTTP server listening on port 8000.

\*\***This will download the files over http which is not encrypted,   
so ensure you trust the network you're downloading the zip file over**\*\*

```
mkdir -p ~/files_for_windows
cp /opt/lme/files_for_windows.zip ~/files_for_windows/
cd ~/files_for_windows
python3 -m http.server
```

After that you can use any web browser to navigate to `http://<LINUX-IP>:8000` where `<LINUX-IP>` is the IP address of the Linux server. Click the file named `files_for_windows.zip` to download it to your downloads folder. **Be sure to stop the HTTP server after you download the file.**

  - Alternatively, you can also run the following in a Powershell window on the ELK server to download the file to your desktop (make sure the HTTP server is running before you run this command):

    ```
    wget http://<LINUX-IP>:8000/files_for_windows.zip -OutFile $env:UserProfile\Desktop\files_for_windows.zip
    ```

## 3.3 Configuring Winlogbeat on Windows Event Collector Server

Now you need to install Winlogbeat on the Windows Event Collector. Winlogbeat reads Event Viewer on the Windows Event Collector (based upon a configuration file) and sends them to your Linux server.

### 3.3.1 Files Required

Whichever method you used in [step 3.2.4](#324-download-files-for-windows-event-collector), you should have downloaded the `files_for_windows.zip` archive containing the following files:
  - root-ca.crt
  - wlbclient.key
  - wlbclient.crt
  - winlogbeat.yml

These are certificates, keys, and configuration files required for the Event Collector to securely transfer event logs to the Linux ELK server.

**Download winlogbeat:**

You will also require the latest supported version of `Winlogbeat`. You can download it as a zip file from Elastic's website [here](https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-8.5.0-windows-x86_64.zip). **The current version officially supported by LME is 8.5.0.**

### 3.3.2 Install Winlogbeat
On the Windows Event Collector server extract the 'files_for_windows.zip' archive and copy the 'lme' folder (contained within 'tmp' inside the extracted files) to the following location:

```
C:\Program Files\lme
```
Next, unzip the downloaded winlogbeat zip file and copy its contents into the ```C:\Program Files\lme\``` folder. The resultant folder should look like the image below, noting that the specific version of winlogbeat in use may differ slightly:

![Winlogbeat Install Location](/docs/imgs/winlogbeat-location.png)
<p align="center">
Figure 3: Winlogbeat Install Location
</p>

Then, move the 'winlogbeat.yml' file located at ```C:\Program Files\lme\winlogbeat.yml``` into the winlogbeat folder ```C:\Program Files\lme\winlogbeat-8.[x].[y]-windows-x86_64```, overwriting the existing file when prompted to do so.

Now, open PowerShell as an administrator and run the following command from the winlogbeat directory, allowing the script to run if prompted to do so: ```./install-service-winlogbeat.ps1```

If you receive a permissions error you can run ```Set-ExecutionPolicy Unrestricted -Scope Process``` to be able to run the installer.

![Winlogbeat Install Script](/docs/imgs/winlogbeat-install.png)
<p align="center">
Figure 4: Winlogbeat Install Script

Then in the same PowerShell window start the winlogbeat service by running:

```
Start-Service winlogbeat
```

Lastly, open ```services.msc``` as an administrator, and make sure the winlogbeat service is installed, is set to start automatically, and is running:

![Winlogbeat Service Running](/docs/imgs/winlogbeat-running.png)
<p align="center">
Figure 5: Winlogbeat Service Running


## Trusting the certs that secure LME's services

Theres a few steps we need to follow to trust the self-signed cert: 
1. Grab the self-signed certificate authority for LME (done in step [3.2.4](#324-download-files-for-windows-event-collector)).
2. Have our clients trust the certificate authority (see command below).

This will trust the self signed cert and any other certificates it signs. If this certificate is stolen by an attacker, they can use it to trick your browser into trusting any website they setup. Make sure this cert is kept safe and secure. 

We've already downloaded the self-signed cert in previous steps in Chapter 3, so now we just need to tell Windows to trust the certificates our self-signed cert has setup for our LME services.

### Commands: 
These commands should be run on every computer that will access the Kibana front end for LME's Elastic deployment. (i.e  https://<LINUX_SERVER_IP/HOSTNAME>)

1. Start a Powershell prompt as administrator
2. Import the certificate:
```
Import-Certificate -FilePath 'C:\Program Files\lme\root-ca.crt' `
  -CertStoreLocation "Cert:\LocalMachine\Root"
```

## Chapter 3 - Checklist

1. Check `services.msc` on the Windows Event Collector. Does `winlogbeat` show as running and automatic?
2. On the Linux machine, check the output of `sudo docker stack ps lme` . You should see `lme_elasticsearch`, `lme_kibana`, and `lme_logstash` all in the 'current' state of ‘running’
3. You should now be able to access Kibana by browsing to `https://<LINUX_SERVER_IP/HOSTNAME>`, where `<LINUX_SERVER_IP/HOSTNAME>` is the IP or hostname of your Linux server. The username and password is provided from the script in [Section 3.2.2: Running the Script](#322-running-the-script), specifically the credentials under `Web Interface login` (the username is elastic).

### Troubleshooting

Should problems arise in transferring logs from the Event Collector to the ELK server, useful logs can be found in `%PROGRAMDATA%\winlogbeat` on the Windows Event Collector. See [Troubleshooting: Chapter 3](/docs/markdown/reference/troubleshooting.md#chapter-3---installing-the-elk-stack-and-retrieving-logs) for more information.

## Now move onto [Chapter 4 - Post Install Actions ](/docs/markdown/chapter4.md)
