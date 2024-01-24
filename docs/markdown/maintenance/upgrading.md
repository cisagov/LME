# Upgrading

Please see https://github.com/cisagov/LME/releases/ for our latest release.

Below you can find the upgrade paths that are currently supported and what steps are required for these upgrades. Note that major version upgrades tend to include significant changes, and so will require manual intervention and will not be automatically applied, even if auto-updates are enabled.

Applying these changes is automated for any new installations. But, if you have an existing installation, you need to conduct some extra steps. **Before performing any of these steps it is advised to take a backup of the current installation using the method described [here](/docs/markdown/maintenance/backups.md).**

## 1. Finding your LME version (and the components versions)
When reporting an issue or suggesting improvements, it is important to include the versions of all the components, where possible. This ensures that the issue has not already been fixed! 

### 1.1. Windows Server
* Operating System: Press "Windows Key"+R and type ```winver```
* WEC Config: Open EventViewer > Subscriptions > "LME" > Description should contain version number
* Winlogbeat Config: At the top of the file C:\Program Files\lme\winlogbeat.yml there should be a version number.
* Winlogbeat.exe version: Using PowerShell, navigate to the location of the Winlogbeat executable ("C:\Program Files\lme\winlogbeat-x.x.x-windows-x86_64") and run `.\winlogbeat version`.
* Sysmon config: From either the top of the file or look at the status dashboard
* Sysmon executable: Either run sysmon.exe or look at the status dashboard

### 1.2. Linux Server
* Docker: on the Linux server type ```docker --version```
* Linux: on the Linux server type ```cat /etc/os-release```
* Logstash config: on the Linux server type ```sudo docker config inspect logstash.conf --pretty```


## 2. Upgrade from versions prior to v0.5
LME does not support upgrading directly from versions prior to v0.5 to v1.0. Prior to switching to CISA's repo, first upgrade to the latest version of LME published by the NCSC (v0.5.1). Then follow the instructions above to upgrade to v1.0.


## 3. Upgrade from v0.5 to v1.0.0

Since LME's transition from the NCSC to CISA, the location of the LME repository has changed from `https://github.com/ukncsc/lme` to `https://github.com/cisagov/lme`. To obtain any further updates to LME on the ELK server, you will need to transition to the new git repository. Because vital configuration files are stored within the same folder as the git repo, it's simpler to copy the old LME folder to a different location, clone the new repo, copy the files and folders unique to your system, and then optionally delete the old folder. You can do this by running the following commands:


```
sudo mv /opt/lme /opt/lme_old
sudo git clone https://github.com/cisagov/lme.git /opt/lme
sudo cp -r /opt/lme_old/Chapter\ 3\ Files/certs/ /opt/lme/Chapter\ 3\ Files/
sudo cp /opt/lme_old/Chapter\ 3\ Files/docker-compose-stack-live.yml /opt/lme/Chapter\ 3\ Files/
sudo cp /opt/lme_old/Chapter\ 3\ Files/get-docker.sh /opt/lme/Chapter\ 3\ Files/
sudo cp /opt/lme_old/Chapter\ 3\ Files/logstash.edited.conf /opt/lme/Chapter\ 3\ Files/
sudo cp /opt/lme_old/files_for_windows.zip /opt/lme/
sudo cp /opt/lme_old/lme.conf /opt/lme/
sudo cp /opt/lme_old/lme_update.sh /opt/lme/
```
Finally, you'll need to grab your old dashboard_update password and add it into the new dashboard_update script: 
```
OLD_Password=[OLD_PASSWORD_HERE]
sudo cp /opt/lme/Chapter\ 3\ Files/dashboard_update.sh /opt/lme/
sed -i "s/dashboardupdatepassword/$OLD_Password/g" /opt/lme/dashboard_update.sh
```


### 3.1. ELK Stack Update
You can update the ELK stack portion of LME to v1.0 (including dashboards and ELK stack containers) by running the following on the Linux server:

```
cd /opt/lme/Chapter\ 3\ Files/
sudo ./deploy.sh upgrade
```
**The last step of this script makes all files only readable by their owner in /opt/lme, so that all root owned files with passwords in them are only readable by root. This prevents a local unprivileged user from gaining access to the elastic stack.**

Once the deploy update is finished, next update the dashboards that are provided alongside LME to the latest version. This can be done by running the below script, with more detailed instructions available [here](/docs/markdown/chapter4.md#411-import-initial-dashboards):

\*\**NOTE:*\*\* *You may need to wait several minutes for Kibana to successfully initialize after the update before running this script during the upgrade process. If you encounter a "Failed to connect" error or an "Entity Too Large" error wait for several minutes before trying again.*

##### Optional Substep: Clear out old dashboards
**Skip this step if you don't want to clear out the old dashboards**

The LME team  will not be maintaining any old dashboards from the old NCSC LME version, so if you would like to clean up your LME you can remove the dashboards by navigating to: https://<SERVER_DOMAIN/IP>/app/management/kibana/objects

From there select all the dashboards in the search: `type:(dashboard)` and delete them. 
Then you can re-import the new dashboards like above.

If you have any custom dashboards you should download them manually and add them to the repo as discussed in the new dashboard's folder [README](/Chapter 4 Files/dashboards/Readme.md).

Most data from the old LME should display just fine in the new dashboards, but there could be some issues, so please feel free to file an issue if there are problems.


```
sudo /opt/lme/dashboard_update.sh
```

The rules built-in to the Elastic SIEM can then be updated to the latest version by following the instructions listed in [Chapter 4](/docs/markdown/chapter4.md#42-enable-the-detection-engine) and selecting the option to update the prebuilt rules when prompted, before making sure all of the rules are activated:

![Update Rules](/docs/imgs/update-rules.png)



### 3.2. Winlogbeat Update
The winlogbeat.yml file used with LME v0.5.1 is not compatible with Winlogbeat 8.5.0, the version used with LME v1.0. As such, running `./deploy.sh update` from step 1.1.1 regenerates a new config file.

**Your client may still authenticate and push logs to elasticsearch, but for both the security of the client and your LME setup we suggest you still update**

To update Winlogbeat:
1. Copy files_for_windows.zip to the Event Collector, following the instructions listed under [3.2.4 Download Files for Windows Event Collector](/docs/markdown/chapter3/chapter3.md#324-download-files-for-windows-event-collector).
2. From an elevated PowerShell session, navigate to the location of the Winlogbeat executable ("C:\Program Files\lme\winlogbeat-x.x.x-windows-x86_64\") and then run `./uninstall-service-winlogbeat.ps1`
3. Re-install Winlogbeat, using the new copy of files_for_windows.zip, following the instructions listed under [3.3 Configuring Winlogbeat on Windows Event Collector Server](/docs/markdown/chapter3/chapter3.md#33-configuring-winlogbeat-on-windows-event-collector-server)

### 3.3. Network Share Updates
LME v1.0 made a minor change to the file structure used in the SYSVOL folder, so a few manual changes are needed to accommodate this.
1. Set up the SYSVOL folder as described in [2.2.1 - Folder Layout](/docs/markdown/chapter2.md#221---folder-layout).
2. Replace the old version of update.bat with the [latest version](/Chapter%202%20Files/GPO%20Deployment/update.bat).
3. Update the path to update.bat used in the LME-Sysmon-Task GPO (refer to [2.2.3 - Scheduled task GPO Policy](/docs/markdown/chapter2.md#223---scheduled-task-gpo-policy)).

### 3.4. Checklist
1. Have the ELK stack components been upgraded on the Linux server? While on the Linux server, run `sudo docker ps | grep lme`. Version 8.7.1 of Logstash, Kibana, and Elasticsearch should be running.
2. Has Winlogbeat been updated to version 8.5.0? From Event Collector, using PowerShell, navigate to the location of the Winlogbeat executable ("C:\Program Files\lme\winlogbeat-x.x.x-windows-x86_64") and run `.\winlogbeat version`.
3. Is the LME folder inside SYSVOL properly structured? Refer to the checklist listed at the end of chapter 2.
4. Are the events from all clients visible inside elastic? Refer to [4.1.2 Check you are receiving logs](/docs/markdown/chapter4.md#412-check-you-are-receiving-logs).

## 4. Upgrade to v1.3.1 

This is a hotfix to the install script and some additional troubleshooting steps added to documentation on space management. Unless you're encountering problems with your current installation, or if your logs are running out of space, there's no need to upgrade to v1.3.1, as it doesn't offer any additional functionality changes.

## 5. Upgrade to v1.3.2 

This is a hotfix to address dashboards which failed to load on a fresh install of v1.3.1. If you are currently running v1.3.0, you do not need to upgrade at this time.  If you are running versions **before** 1.3.0 or are running v1.3.1, we recommend you upgrade to the latest version.

Please refer to the [Upgrading to latest version](/docs/markdown/maintenance/upgrading.md#upgrading-to-latest-version) to apply the hotfix.

## 6. Upgrade to latest version 
To fetch the latest changes, on the Linux server, run the following commands as root:
```
git pull
git checkout main
cd /opt/lme/Chapter\ 3\ Files/
sudo ./deploy.sh uninstall
cd /opt/lme
cd Chapter\ 3\ Files/
sudo ./deploy.sh install
```

The deploy.sh script should have now created new files on the Linux server at location /opt/lme/files_for_windows.zip . This file needs to be copied across and used on the Windows Event Collector server like it was explained in Chapter 3 sections [3.2.4 & 3.3 ](/docs/markdown/chapter3/chapter3.md#324-download-files-for-windows-event-collector). 

