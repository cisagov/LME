# Dashboard Descriptions

## Purpose   
Logging Made Easy (LME) releases new dashboards on GitHub periodically. Here are the dashboard descriptions.

## User Human Resources  

The User Human Resources Dashboard provides a comprehensive overview of network activity and displays domains, users, workstations, activity times and days of the week. It includes details on general logon events, logoff events and distinguishes between in-person and remote logons. Analogous to a security guard monitoring a camera, the dashboard facilitates network monitoring by revealing overall network traffic, user locations, peak hours and the ratio of remote-to-in-person logons. Users can filter and analyze individual or specific computer activity logs. 

## Computer Software Overview

The Computer Software Overview Dashboard displays application usage on host computers, logging events for application failures, hangs and external connection attempts. Monitoring application usage is crucial for assessing network health, as frequent crashes may indicate larger issues, and applications making frequent external requests could signal malicious activity.  

## Security Log

The Security Log Dashboard actively presents forwarded security log events, tallies failed logon attempts, identifies computers with failed logon events, specifies reasons for failed logons and distinguishes types of logons and reports on credential status (clear text or cached). It also discloses whether the event log or Windows Security audit log is cleared, highlights user account changes and notes the assignment of special privileges to a logon session. Users can quickly detect unusual events, prompting further investigation and remediation actions. 

## Process Explorer 

The Process Explorer Dashboard thoroughly monitors networks, tracks processes, users, processes per user, files, filenames in the download directory, Sysmon process creation and registry events. It offers user-friendly filtering for process names and process identifiers or PID’s. The download directory is often targeted for initial malware installations due to lenient write privileges. This dashboard investigates unusual registry changes and closely examine spikes in processes created by specific users, as these could indicate potential malicious activity. 

## Sysmon Summary

The Sysmon Summary Dashboard highlights Sysmon events and features event count, event types, the percentage breakdown by event code and top hosts generating Sysmon data. Vigilance towards any deviations or shifts in activity levels helps administrators to promptly identify both desired and undesired activities. 

## User Security

The User Security Dashboard provides a comprehensive view of network activity and showcases logon attempts, user logon/logoff events, logged-on computers and detailed network connections by country and protocol. Additionally, it highlights critical information such as PowerShell events, references to temporary files and Windows Defender alerts for malware detection and actions taken. The dashboard supports effective monitoring by allowing users to filter events based on users, domains and hosts. Understanding the nature and origin of network connections is vital, and the dashboard facilitates the identification of suspicious activities, enabling operators to target their inquiries for enhanced network health assessment. 

## Alert

The Alert Dashboard enables users to define rules that detect complex conditions within networks/environments. It also uses trigger actions in case of suspicious activities. These alerts contain pre-built rules that detects suspicious activities.  There are options that schedule how these suspicious activities are detected and actions taken when these conditions are detected. 

## Healthcheck 

The HealthCheck Dashboard gives users the ability to view different processes such as unexpected shutdowns, events by each machine, total hosts and total number of logged in admins with data that is based on a selected date range.  Users can verify the health of their system by observing events such as if there are more admin users than expected or if an unexpected shutdown occurs. 

##  Policy Changes and System Activity

The Policy Changes and System Activity dashboard enables users to monitor policy changes and important system activity. Users will be able to monitor the status of their firewall, including when it is turned on, off, its settings are changed, or exception rules are added or modified. This dashboard will also show when firewall, audit, or Kerberos policies are changed on their domain. Users will also be able to monitor when their PCs are turned on, off, and when RPC (Remote Procedure Call) connections are attempted on their domain. 

## Identity Access Management

The Identity Access Management dashboard provides users with a collection of important security events involving identity and critical object access. This includes when registry objects, task scheduler jobs, and when password hashes are accessed. Users will also be able to monitor when passwords are reset, changed, and when users are locked out of their accounts. This dashboard also tracks when the default domain policy is changed which involves the domain password policy. 

## Privileged Activity log Dashboard
The Privileged Activity Log Dashboard enables users to carry on audits related to non-sensitive and sensitive events by showcasing the number of privileged service attempts, sensitive privilege attempts and non-sensitive privilege attempts made per host name. It also shows the number of processes created and terminated per host name. Such as process creation count, process termination counts as well as assigned token creation count per host.

## Credential Access logs Dashboard
The Credential Access logs Dashboard, focuses on account logon and account logoff audit events. In this dashboard, users will be able to monitor, audit logon attempts per hosts, logon using explicit credential attempts, account lockout attempts per host, special logon attempts per hosts, disconnection attempts, and credential validation attempts per host. Dashboard panels will also showcase Kerberos authentication services per host.



For more information or to seek additional help, [Click Here](https://github.com/cisagov/LME) 
