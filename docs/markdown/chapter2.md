# Chapter 2 – Installing Sysmon

## Chapter Overview
In this chapter you will:
* Setup a GPO or SCCM job to deploy Sysmon across your clients.

## 2.1 Introduction
Sysmon is a Windows service developed by Microsoft to generate rich Windows event logs with much more information than the default events created in Windows. Having comprehensive logs is critical in monitoring your system and keeping it secure. The information contained within Sysmon's logs are based on settings defined in an XML configuration file and can be configured to your liking, though templates will be provided to get you started.

**By following this guide and using Sysmon, you are agreeing to the following EULA.
Please read this before continuing.
https://docs.microsoft.com/en-us/sysinternals/license-terms**

LME supports either GPO or SCCM Deployment. It is your choice which of these you use, but you should not use both. GPO configuration is recommended, as the process very closely resembles the steps taken in [Chapter 1](/docs/markdown/chapter1/chapter1.md).

## 2.2 GPO Deployment

Group Policy Object (GPO) deployment involves adding a GPO to the LME clients that creates a Windows 'Scheduled Task' to install Sysmon. The 'Scheduled Task' will periodically connect to a network folder location and run an install script called 'update.bat' to install Sysmon or modify an existing installation.

Using Microsoft Group Policy to deploy LME requires two main things:
- A location to host the configuration and executables. (e.g. SYSVOL)
- A Group Policy Object (GPO) to create a scheduled task.

If you get stuck while trying to add and configure GPO's, refer back to Chapter 1 for a quick refresher.

### 2.2.1 - Folder Layout
A centralized network folder accessible by all machines that are going to be running Sysmon is needed. We suggest inside the SYSVOL directory as a suitable place since this is configured by default to have very restricted write permissions.
**It is extremely important that the folder contents cannot be modified by users, hence recommending SYSVOL folder.**

The SYSVOL directory is located on the Domain Controller at `C:\Windows\SYSVOL\SYSVOL\<YOUR-DOMAIN-NAME>`, where "YOUR-DOMAIN-NAME" refers to your active directory domain name. You can also access it over the network at `\\<YOUR-DOMAIN-NAME>\SYSVOL\<YOUR-DOMAIN-NAME>`. As you are adding files to the SYSVOL directory throughout this chapter, you can either add them on the Domain Controller locally or over the network.

First create an empty directory in SYSVOL (or some other network location of your choosing) called `LME`. Then inside that newly created folder, create another directory called `Sysmon` Then download the below files and copy them to the new directory (if you're using the SYSVOL directory, the path would be ```\\<YOUR-DOMAIN-NAME>\SYSVOL\<YOUR-DOMAIN-NAME>\LME\Sysmon```).
- Sysmon64.exe - https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon
- sigcheck64.exe  - https://docs.microsoft.com/en-us/sysinternals/downloads/sigcheck
- sysmon.xml -
  - Either [Olaf Hartong's Modular Sysmon](https://github.com/olafhartong/sysmon-modular/blob/master/sysmonconfig.xml) or [SwiftOnSecurity's Sysmon](https://github.com/SwiftOnSecurity/sysmon-config/blob/master/sysmonconfig-export.xml) config are the recommended Sysmon configuration (pick one).
  - **Using the SwiftOnSecurity XML will ensure the best compatibility with the pre-made dashboards, while Olaf Hartong's modular XML will collect additional data and may be suitable when more robust monitoring is required.**
  - These configuration options are a good starting point, but more advanced users will benefit from customization to include/exclude events.
  - **You will need to rename the downloaded file to sysmon.xml.**
- update.bat - Found within the folder downloaded in [step 1.3](/docs/markdown/chapter1/chapter1.md#13-download-lme), `Chapter 2 Files/GPO Deployment/update.bat`. (Based on work by Ryan Watson & Syspanda.com)

Looking in the folder you just created, you should now see the following structure:

```
NETWORK_SHARE (e.g. SYSVOL)
└── LME
	├── Sysmon
		├── Sysmon64.exe
		├── sysmon.xml
		└── update.bat
	└── sigcheck64.exe
```

## 2.2.2 Configuring the Update Scripts (If Not SYSVOL)

**If you used the recommended SYSVOL directory, you may skip this step.**

Otherwise, edit the variable `NETDIR` in `\Sysmon\update.bat` to match the path to your `LME` folder. For example, if my `LME` folder were located at `\\my-share\read-only\LME`, the line in the scripts should look like this:

```
SET NETDIR=\\my-share\read-only\LME
```

The line to edit is near the beginning of both scripts. See the below figure for reference:

![Edit the NETDIR Variable in Both Update Scripts](/docs/imgs/edit-update-script.png)
<p align="center">
Figure 1: Edit the NETDIR Variable in Both Update Scripts
</p>

### 2.2.3 - Scheduled task GPO Policy
This section sets up a scheduled task to run update.bat (stored on a network folder), distributed through Group Policy.

1. From a domain controller, open the Group Policy Management editor (Windows key + R, "gpmc.msc").
2. Create a new GPO, "LME-Sysmon-Task."
3. Right-click the newly created "LME-Sysmon-Task" object. Select "Import Settings..."
4. Hit "Next" until you reach the "Backup Location" page of the Wizard. **NOTE:** the "Backup Location" page of the wizard deals with importing settings from a backup, not to be confused with the "Backup GPO" page, which deals with creating a new backup with the current settings.
5. When prompted to specify a "Backup Location," specify `LME-1.0\Chapter 2 Files\GPO Deployment\Group Policy Objects\`, where `LME-1.0` refers to the folder downloaded in [step 1.3](/docs/markdown/chapter1/chapter1.md#13-download-lme).
6. On the "Source GPO" page, select "LME-Sysmon-Task." Click "Next" then "Finish."
7. Right click the same test Organizational Unit (OU) used for the clients in Chapter 1, click "Link an Existing GPO...," then select "LME-Sysmon-Task." Once the GPO is confirmed as working in your environment then you can link the GPO to a larger OU to deploy LME further.
8. Right click the Lme-Sysmon-Task GPO and select "Edit."
9. Navigate to  `Computer Configuration\Preferences\Control Panel Settings\Scheduled Tasks\`
10. Double click "LME-Sysmon-Task," then switch to the "Actions" tab.
11. Click "Start a program," then "Edit."
12. Under "Program/Script," click "Browse," then find and select the "update.bat" file, within the SYSVOL folder (see Figure 2). **NOTE:** the SYSVOL path needs to be manually changed to be in the format of a network path. It **cannot** begin with "C:\\Windows".  See Figure 2 for clarification.
13. Click "Apply" to apply the changes to the GPO.
    
![image](/docs/imgs/sysmon-task-properties.png)
<p align="center">
Figure 2: Specify the path to the update.bat file as the action for the scheduled test.
</p>

At this point, the GPO should be properly configured, but without additional intervention, it could take up to 24 hours for the scheduled task to activate. Before it does, Sysmon will not show up as a service on the clients. However, further steps can be taken to ensure immediate installation.
- View the "Triggers" tab of the "LME-Sysmon-Task-Properties" page. Click "Daily," then "Edit..." Note the start time specified. Each day, starting at that specific time, the LME-Sysmon-Task will run, repeating every 30 minutes. If that time has already passed on the day you created the GPO, the task won't activate for the first time until the following day. Generally speaking, you'll want to set the time to the beginning of the day for complete coverage, but you may consider adjusting it temporarily for testing purposes so that it will activate while you can observe it.
- By default, Windows will update group policy settings only every 90 minutes. You can manually trigger a group policy update by running `gpupdate /force` in an elevated Command Prompt window on a given client to apply the GPO to that specific client immediately. 


## 2.3 SCCM Deployment
While SCCM deployment is not usually the first choice for the deployment of Sysmon we have included an example install and uninstall PowerShell along with a detection criteria that works with SCCM.

Files for this portion of the tutorial can be found [here](/Chapter%202%20Files/SCCM%20Deployment/).

Install Program:
```powershell.exe -Executionpolicy unrestricted -file Install_Sysmon64.ps1```

Uninstall program:
```powershell.exe -Executionpolicy unrestricted -file Uninstall_Sysmon64.ps1```

Detection method: `File exists - C:\Windows\sysmon64.exe`

## Chapter 2 - Checklist
1. Ensure that your files and folders in the network share are nested and named correctly. Remember that in Windows, case in filenames or folders does not matter.

```
NETWORK_SHARE (e.g. SYSVOL)
└── LME
	├── Sysmon
		├── Sysmon64.exe
		├── sysmon.xml
		└── update.bat
	└── sigcheck64.exe
```

2. Do you have the Sysmon service running on a sample of the clients? You can verify this by logging in to one of the clients and pressing Windows key + R, running "services.msc," and searching to see if Sysmon is listed as an active service.
3. Is the Sysmon Eventlog showing data? On one of the clients, open Event Viewer and look in Applications and Services Logs/Microsoft/Windows/Sysmon/Operational.
4. Are you seeing Sysmon logs show up on the Event Collector? On the Event Collector, open Event Viewer and look in the Windows Logs/Forwarded Events folder.

If any problems are found, restart all of your machines and see [Troubleshooting | Chapter 2 - Installing Sysmon](reference/troubleshooting.md#chapter-2---installing-sysmon) for additional tips.

## Now move onto [Chapter 3 - Installing the ELK Stack and Retrieving Logs](/docs/markdown/chapter3/chapter3.md)
