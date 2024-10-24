# Prerequisites


## What kind of IT skills do I need to install LME?

The LME project can be installed by someone at the skill level of a systems administrator or enthusiast. If you have ever…

* Installed a Windows server and connected it to an Active Directory domain
* Changed firewall rules
* Installed a Linux operating system, and logged in over SSH.

… then you are likely to have the skills to install LME!

We estimate that you should allow a couple of hours to run through the entire installation process.  While we have automated steps where we can and made the instructions as detailed as possible, installation will require more steps than simply using an installation wizard.

## High level overview diagram of the LME system

![diagram](/docs/imgs/lme-architecture-v2.jpg)

Please see the [main readme](/README.md#Diagram) for a more detailed description

## How much does LME cost?

The portions of this package developed by the United States government are distributed under the Creative Commons 0 ("CC0") license. Portions created by government contractors at the behest of CISA are provided with the explicit grant of right to use, modify, and redistribute the code subject to this statement and the existing license structure. All other portions, including new submissions from all others, are subject to the Apache License, Version 2.0.
This project (scripts, documentation, and so on) is licensed under the [Apache License 2.0 and Creative Commons 0](../../LICENSE).

The design uses open software which comes at no cost to the user, we will maintain a pledge to ensure that no paid software licenses are needed above standard infrastructure costs (With the exception of Windows Operating system Licensing).

You will need to pay for hosting, bandwidth and time; for an estimate of server specs that might be needed see this [blogpost from elasticsearch](https://www.elastic.co/blog/benchmarking-and-sizing-your-elasticsearch-cluster-for-logs-and-metrics). Then use your estimated server specs to determine a price for an on prem or cloud deployment.


## Navigating this document

A **Chapter Overview** appears at the top of each chapter to briefly signpost the work of the following section.

Text in **bold** means that you have to make a decision or take an action that needs particular attention.


Text in *italics* is an easy way of doing something, such as running a script. Double check you are comfortable doing this. A longer, manual, way is also provided.


```
Text in boxes is a command you need to type 
```

You should follow each chapter in order, and complete the checklist at the end before continuing.

## Scaling the solution
To keep LME simple, our guide only covers single server setups. It’s difficult to estimate how much load the single server setup will take.
It’s possible to scale the solution to multiple event collectors and ELK nodes, but that will require more experience with the technologies involved. We plan to publish documentation for scaling LME in the future.

## Required infrastructure

To begin your Logging Made Easy installation, you will need access to (or creation of) the following servers:

* A server with 2 processor cores and at least 8GB RAM. We will install the Windows Event Collector Service on this machine, set it up as a Windows Event Collector (WEC), and join it to the domain.
* An ubuntu linux 22.04 server. We will install our database (Elasticsearch) and dashboard software on this machine. This is all taken care of through Podman containers.

### Minimum Hardware Requirements:
   -  CPU: 2 processor cores, 4+ recommended
   -  MEMORY: 16GB RAM,  (32GB+ recommended by [Elastic](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-hardware-prereq.html)),
   - STORAGE: dedicated 128GB storage for ELK (not including storage for OS and other files)
     - This is estimated to only support ~17 clients of log streaming data/day, and Elasticsearch will automatically purge old logs to make space for new ones. We **highly** suggest more storage than 128GB for any other sized enterprise network.
		 
#### confirm these settings:
to check memory run this command, look under the "free" column
```bash
$ free -h 
total        used        free      shared  buff/cache   available
Mem:            31Gi       6.4Gi        22Gi       4.0Mi       2.8Gi        24Gi
Swap:             0B          0B          0B
```

to check the number of CPUs 
```bash
$ lscpu | egrep 'CPU\(s\)'
```

to check hardware storage, typically the /dev/root will be your main filesystem. The number of gigabytes available is in the Avail column
```bash
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       124G   13G  112G  11% /
```

## Where to install the servers

Servers can be either on premise, in a public cloud or private cloud. It is your choice, but you'll need to consider how to network between the clients and servers.

## What firewall rules are needed?
Please see our cloud documentation for a discussion on firewalls [CLOUD](/docs/markdown/loggging-guidance/cloud.md). 

The main point is you need to make sure your client machine you want to monitor can hit the main LME ports in the readme [LINK](/README.md#required-ports) wherever you intend to run your LME server.


