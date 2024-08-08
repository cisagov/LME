![N|Solid](/docs/imgs/cisa.png)

[![Downloads](https://img.shields.io/github/downloads/cisagov/lme/total.svg)]()

# Logging Made Easy
Initially created by NCSC and now maintained by CISA, Logging Made Easy is a self-install tutorial for small organizations to gain a basic level of centralized security logging for Windows clients and provide functionality to detect attacks. It's the coming together of multiple open software platforms which come at no cost to users, where LME helps the reader integrate them together to produce an end-to-end logging capability. We also provide some pre-made configuration files and scripts, although there is the option to do it on your own.

Logging Made Easy can:
- Show where administrative commands are being run on enrolled devices
- See who is using which machine
- In conjunction with threat reports, it is possible to query for the presence of an attacker in the form of Tactics, Techniques and Procedures (TTPs)

## Disclaimer

**LME is currently still early in development.**

***If you have an existing install of the LME Alpha (v0.5 or older) some manual intervention will be required in order to upgrade to the latest version, please see [Upgrading](/docs/markdown/maintenance/upgrading.md) for further information.***

**This is not a professional tool, and should not be used as a [SIEM](https://en.wikipedia.org/wiki/Security_information_and_event_management).**

**LME is a 'homebrew' way of gathering logs and querying for attacks.**

We have done the hard work to make things simple. We will tell you what to download, which configurations to use and have created convenient scripts to auto-configure wherever possible.

The current architecture is based upon Windows Clients, Microsoft Sysmon, Windows Event Forwarding and the ELK stack.

We are **not** able to comment on or troubleshoot individual installations. If you believe you have have found an issue with the LME code or documentation please submit a [GitHub issue](https://github.com/cisagov/lme/issues). If you have a question about your installation, please visit [GitHub Discussions](https://github.com/cisagov/lme/discussions) to see if your issue has been addressed before.

## Who is Logging Made Easy for?

From single IT administrators with a handful of devices in their network to larger organizations.

LME is for you if:

*	You don’t have a [SOC](https://en.wikipedia.org/wiki/Information_security_operations_center), SIEM or any monitoring in place at the moment.
*	You lack the budget, time or understanding to set up your own logging system.
*	You recognize the need to begin gathering logs and monitoring your IT.
*	You understand that LME has limitations and is better than nothing - but no match for a professional tool.

If any, or all, of these criteria fit, then LME is a step in the right direction for you.

LME could also be useful for:

*	Small isolated networks where corporate monitoring doesn’t reach.

## Overview
The LME architecture consists of 3 groups of computers, as summarized in the following diagram:
![High level overview](/docs/imgs/OverviewDiagram.png)

<p align="center">
Figure 1: The 3 primary groups of computers in the LME architecture, their descriptions and the operating systems / software run by each.
</p>

## Table of contents

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

### Maintenance:
 - [Backups](/docs/markdown/maintenance/backups.md)  
 - [Upgrading](/docs/markdown/maintenance/upgrading.md)  
 - [Certificates](/docs/markdown/maintenance/certificates.md)  
