# Chapter 1 – Setting up Windows Event Forwarding

![Event Forwarding overview](/docs/imgs/eventforwarding_overview.jpg)
<p align="center">
Figure 1: Finished state of Chapter 1
</p>

## Chapter Overview
In this chapter you will:
* Add some Group Policy Objects (GPOs) to your Active Directory (AD).
* Configure the Windows Event Collector listener service.
* Configure clients to send logs to this box.

## 1.1 Introduction
This chapter will cover setting up the built-in Windows functionality for event forwarding. This effectively takes the individual events (such as a file being opened) and sends them to a central machine for processing. This is similar to the setup discussed in this [Microsoft blog](https://docs.microsoft.com/en-us/windows/security/threat-protection/use-windows-event-forwarding-to-assist-in-intrusion-detection).

Only a selection of events will be sent from the client's ‘Event Viewer’ to a central ‘Event Collector’. The events will then be uploaded to the database and dashboard in Chapter 3.
This chapter will require the clients and event collector to be Active Directory domain joined and the event collector to be either a Windows server or a Windows client operating system.

## 1.2 Firewall rules and where to host
You will need TCP port 5985 open between the clients and the Windows Event Collector. You also need port 5044 open between the Windows Event Collector and the Linux server.

We recommend that this traffic does not go directly across the Internet, so you should host the Windows Event Collector on the local network, in a similar place to the Active Directory server.

## 1.3 Download LME
There are several files within the LME repo that need to be available on a domain controller. These files will be needed for both Chapters 1 and 2. While there are multiple ways to accomplish this, one simple method is to download the latest release package.

1. While on a domain controller, download [the desired release](https://github.com/cisagov/lme/releases/).
2. Open File Explorer, locate and extract the release file downloaded in step 1, for example, LME-1.0.zip.
3. Move the LME folder somewhere safe. There is no set location where this folder is required to be, but it should be saved somewhere it won't be inadvertently modified or deleted during the installation process. After installation is complete, the folder can be safely deleted.

## 1.4 Import Group Policy objects
Group policy objects (GPOs) are a convenient way to administer technical policies across an Active Directory domain. LME comes with two GPOs that work together to forward events from the client machines to the Event Collector.

![Group Policy Setup](/docs/imgs/gpo.jpg)
<p align="center">
Figure 2: Setting up Group Policy
</p>

#### 1.4.1 Opening GPMC
While on a domain controller, open the Group Policy Management Console by running ```gpmc.msc```. You can run this command by pressing Windows key + R.

![import a new object](/docs/imgs/gpo_pics/gpmc.jpg)
<p align="center">
Figure 3: Launching GPMC
</p>

:hammer_and_wrench: If you receive the error `Windows cannot find 'gpmc.msc'`, see [Troubleshooting: Installing Group Policy Management Tools](/docs/markdown/reference/troubleshooting.md#installing-group-policy-management-tools).

#### 1.4.2 Initialize the GPOs
1. Within the Group Policy Management Console, navigate to the "Group Policy Objects" folder. The exact path will vary, depending on your domain's name. In the example used in Figure 3, the path is `Forest: testme.local / Domains / testme.local / Group Policy Objects`).
2. Right click "Group Policy Objects" and select "New."
3. Create two new GPOs, "LME-WEC-Client" and "LME-WEC-Server." Leave "Source Starter GPO:" as "(none)" for both.
   
![create a new object](/docs/imgs/gpo_pics/create_new_object.jpg)
<p align="center">
Figure 4: Create a new GPO object
</p>

#### 1.4.3 Import the GPO Settings
1. Right-click the newly created "LME-WEC-Client" object. Select "Import Settings..."
2. Hit "Next" until you reach the "Backup Location" page of the Wizard. NOTE: the "Backup Location" page of the wizard deals with _importing_ settings from a backup, not to be confused with the "Backup GPO" page, which deals with creating a new backup with the current settings. 
3. When prompted to specify a "Backup Location," specify `LME-1.0/Chapter 1 Files/Group Policy Objects`, where `LME-1.0` refers to the folder downloaded in step 1.3.
4. On the "Source GPO" page, select "LME-WEC-Client."
5. Click "Next" then "Finish."
6. Repeat the above steps for the "LME-WEC-Server" object, selecting "LME-WEC-Server" on step 4.

#### 1.4.4 Set the Destination for Forwarded Events
1. Right-click the "LME-WEC-Client" object, then select "Edit."
2. Navigate to `Computer Configuration/Policies/Administrative Templates/Windows Components/Event Forwarding/`.
3. Click "Configure Target Subscription Manager." By "SubscriptionManagers," click "Show."
4. Change the FQDN (Fully Qualified Domain Name) to match your Windows Event Collector box name - this option can be seen in Figure 5 below. This domain name needs to be resolvable from each of the clients.
5. After changing the FQDN, click "Apply" then "OK."

![Group Policy Server Name](/docs/imgs/gpoedit.jpg)
<p align="center">
Figure 5: Editing Server Name In Group Policy
</p>

#### 1.4.5 Link the GPOs
To "activate" the GPOs that you previously imported, you need to specify which computers they apply to. Here we describe only one technique of doing this, namely linking GPOs to organizational units (OUs). Advanced users may consider using alternate techniques that better fit their needs. See [Planning GPO Deployment](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/planning-gpo-deployment) for more information.

1. Create an OU to hold a subset of client computers that you want to be included in the LME Client group for testing before rolling out LME site-wide. See [Guide to Organizational Units](/docs/markdown/chapter1/guide_to_ous.md). We recommend starting with just a subset for testing before rolling out LME site-wide.
2. Within the Group Policy Management Console, right click the OU containing the client machines.
3. Click "Link an Existing GPO..."
4. Select "LME-WEC-Client," then click "OK."
5. Before linking the LME-WEC-Server, ensure that the Event Collector has been placed in its own OU. If needed, use the above guide on creating OUs in Step 1.
6. Within the Group Policy Management Console, right click the OU containing the Event Collector.
7. Click "Link an Existing GPO..."
8. Select "LME-WEC-Server," then click "OK."

#### 1.4.6 Restricting Windows Remote Management by IP

Both the LME-WEC-Server and LME-WEC-Client GPOs include a wildcard filter allowing all IP addresses on the host and client to run a Windows Remote Management (WinRM) Listener and to receive inbound connections using this protocol. **We strongly recommend that this is restricted to IP addresses or ranges specific to your network environment.**

An example of this would be if you hosted a LAN with the subnet 192.168.2.0/24, then you could only allows NICs residing within the range 192.168.2.1-192.168.2.254 to run a WinRM listener via the GPO policy.

See Microsoft Document for verification and details: [Installation and configuration for Windows Remote Management](https://docs.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management)

The filter setting is located at "Computer Configuration/Policies/Administrative Templates/Windows Components/Windows Remote Management (WinRM)/WinRM Service/allow remote server management through WinRM".

### 1.5 Windows Event Collector Box Steps
1. On the Windows Event Collector, run Event Viewer by either searching under Start->Run->eventvwr.exe, or under 'Windows Administrative Tools' in the start menu.
2. Click "Subscriptions."
3. If prompted, select "Yes" to start the Windows Event Collector Service (see Figure 6). If no such prompt appears, continue to step 4.

![image](/docs/imgs/event_viewer_prompt.png)
<p align="center">
Figure 6: Start the Windows Event Collector Service, if needed.
</p>

4. Download the [lme_wec_config.xml](/Chapter%201%20Files/lme_wec_config.xml) file to the Windows Event Collector server.
5. Run a command prompt as an administrator, change to the directory containing the wec_config.xml file you just downloaded.
6. Run the command ```wecutil cs lme_wec_config.xml``` within the elevated command prompt. There is no output displayed after running this command.

:hammer_and_wrench: If you receive the error "The forwarder is having a problem communicating with subscription manager..." refer to [Events are not forwarded if the collector is running Windows Server](https://support.microsoft.com/en-in/help/4494462/events-not-forwarded-if-the-collector-runs-windows-server-2019-or-2016). If that does not fix the problem or does not apply, verify that TCP port 5985 is open between the clients and the Windows Event Collector.

## Chapter 1 - Checklist
1. On the Windows Event Collector, Run Event Viewer by either Start->Run->eventvwr.exe, or under ‘Windows Administrative Tools’ in the start menu.
2. Confirm machines are checking in, as per Figure 7. The 'Source Computers' field should contain the number of machines currently connected.

![Group Policy Setup](/docs/imgs/eventviewer.jpg)
<p align="center">
Figure 7: Event Log Subscriptions
</p>

Note that by default, Windows will update group policy settings only every 90 minutes. Because of this, it's possible that the 'Source Computers' field will be 0 the first time you check the subscriptions page. To force an update, logon to one of the client machines, then from an elevated command prompt, run `gpupdate /force.` After doing that, if you return to the event collector, that specific client should show up under the Source Computers tab.

## Now move onto [Chapter 2 – Sysmon Install](/docs/markdown/chapter2.md)
