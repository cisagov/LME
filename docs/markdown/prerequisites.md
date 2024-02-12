# Prerequisites


## What kind of IT skills do I need to install LME?


The LME project can be installed by someone at the skill level of a systems administrator or enthusiast. If you have ever…


* Installed a Windows server and connected it to an Active Directory domain
* Ideally deployed a Group Policy Object (GPO)
* Changed firewall rules
* Installed a Linux operating system, and logged in over SSH.


… then you are likely to have the skills to install LME!

We estimate that you should allow a couple of days to run through the entire installation process, though you can break up the process to fit your schedule. While we have automated steps where we can and made the instructions as detailed as possible, installation will require more steps than simply using an installation wizard.

## High level overview diagram of the LME system

![High level overview](/docs/imgs/chapter_overview.jpg)
<p align="center">
Figure 1: High level overview, linking to documentation chapters
</p>

## How much does LME cost?

The portions of this package developed by the United States government are distributed under the Creative Commons 0 ("CC0") license. Portions created by government contractors at the behest of CISA are provided with the explicit grant of right to use, modify, and redistribute the code subject to this statement and the existing license structure. All other portions, including new submissions from all others, are subject to the Apache License, Version 2.0.
This project (scripts, documentation, and so on) is licensed under the [Apache License 2.0 and Creative Commons 0](../../LICENSE).

The design uses open software which comes at no cost to the user, we will maintain a pledge to ensure that no paid software licenses are needed above standard infrastructure costs (With the exception of Windows Operating system Licensing).

You will need to pay for hosting, bandwidth and time; for an estimate of server specs that might be needed see this [blogpost from elasticsearch](https://www.elastic.co/blog/benchmarking-and-sizing-your-elasticsearch-cluster-for-logs-and-metrics). Then use your estimated server specs to determine a price for an on prem or cloud deployment.


## Navigating this document

A **Chapter Overview** appears at the top of each chapter to briefly signpost the work of the following section.

Text in **bold** means that you have to make a decision or take an action that needs particular attention.


Text in *italics* is an easy way of doing something, such as running a script. Double check you are comfortable doing this. A longer, manual, way is also provided.


``` Text in boxes is a command you need to type ```


You should follow each chapter in order, and complete the checklist at the end before continuing.

## Scaling the solution
To keep LME simple, our guide only covers single server setups. It’s difficult to estimate how much load the single server setup will take.
It’s possible to scale the solution to multiple event collectors and ELK nodes, but that will require more experience with the technologies involved.

## Required infrastructure

To begin your Logging Made Easy installation, you will need access to (or creation of) the following servers:

* A Domain Controller to administer a Windows Active Directory. This is for deploying Group Policy Objects (GPO)
* A server with 2 processor cores and at least 8GB RAM. We will install the Windows Event Collector Service on this machine, set it up as a Windows Event Collector (WEC), and join it to the domain.
   * If budget allows, we recommend having a dedicated server for Windows Event collection. If this is not possible, the WEC can be setup on an existing server, but consider the performance impacts.
   * The WEC server can be Windows Server 2016 (or later) or Windows 8.1 client (or later)
* A Debian-based Linux server. We will install our database (Elasticsearch) and dashboard software on this machine. This is all taken care of through Docker containers.

### Minimum Hardware Requirements:
   -  CPU: 2 processor cores,
   -  MEMORY: 16GB RAM,  (32GB+ recommended by [Elastic](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-hardware-prereq.html)),
   - STORAGE: dedicated 128GB storage for ELK (not including storage for OS and other files)
     - This is estimated to only support ~17 clients of log streaming data/day, and Elasticsearch will automatically purge old logs to make space for new ones. We **highly** suggest more storage than 128GB for any other sized enterprise network.

### Notes:
   * **DO NOT install Docker from the "Featured Snaps" section of the Ubuntu Server install procedure, we install the Docker community edition later.**
   * The deploy script has only been tested on Ubuntu:  `18.04` Long Term Support (LTS) and `22.04` LTS.

## Where to install the servers

Servers can be either on premise, in a public cloud or private cloud. It is your choice, but you'll need to consider how to network between the clients and servers.

## What firewall rules are needed?

![Overview of Network rules](/docs/imgs/troubleshooting-overview.jpg)
<p align="center">
Figure 1: Overview of Network rules
</p>

| Diagram Reference | Protocol information |
| :---: |-------------|
| a | Outbound WinRM using TCP 5985. </br></br> Link is HTTP, underlying data is authenticated and encrypted with Kerberos. </br></br>  See [this Microsoft article](https://docs.microsoft.com/en-us/windows/security/threat-protection/use-windows-event-forwarding-to-assist-in-intrusion-detection) for more information |
| b | Inbound WinRM TCP 5985. </br></br> Link is HTTP, underlying data is authenticated and encrypted with Kerberos. </br></br>  See [this Microsoft article](https://docs.microsoft.com/en-us/windows/security/threat-protection/use-windows-event-forwarding-to-assist-in-intrusion-detection) for more information </br></br> (optional) Inbound TCP 3389 for Remote Desktop management |
| c | Outbound TCP 5044. </br></br> Lumberjack protocol using TLS mutual authentication. |
| d | Inbound TCP 5044. </br> </br> Lumberjack protocol using TLS mutual authentication. </br></br> Inbound TCP 443 for dashboard access </br></br> (optional) Inbound TCP 22 for SSH management |

## Now move onto [Chapter 1 – Setup Windows Event Forwarding](/docs/markdown/chapter1/chapter1.md)
