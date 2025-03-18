# Prerequisites


## What kind of IT skills do I need to install LME?

Users with a background in systems or network administration can download LME. If you have ever…

* Installed a Windows server and connected it to an Active Directory domain
* Changed firewall rules
* Installed a Linux operating system and logged in over SSH

… then you are likely to have the skills to install LME!

We estimate that you should allow half an hour to complete the entire installation process.  We have automated steps where possible and made the instructions as detailed as possible. 

The following time table of real recorded times will provide you a reference of how long the installation may take to complete.

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

## High level overview diagram of the LME system architecture

![diagram](/docs/imgs/lme-architecture-v2.png) 

Please see the [ReadMe](/README.md#Diagram) for a detailed description of of LME's architecture and its components.

## How much does LME cost?

Creative Commons 0 ("CC0") license. Government contractors, working for CISA, provide portions with rights to use, modify, and redistribute under this statement and the current license structure. All other portions, including new submissions, fall under the Apache License, Version 2.0
This project (scripts, documentation, and so on) is licensed under the [Apache License 2.0 and Creative Commons 0](../../LICENSE).

The design uses open software which comes at no cost to the user. CISA will ensure that no paid software licenses are needed above standard infrastructure costs (With the exception of Windows Operating System Licensing).

Users must pay for hosting, bandwidth and time; for an estimate of server specs that might be needed, see this [blogpost from elasticsearch](https://www.elastic.co/blog/benchmarking-and-sizing-your-elasticsearch-cluster-for-logs-and-metrics) then use your estimated server specs to determine a price for an on premise or cloud deployment.


## Scaling the solution
To keep LME simple, our guide only covers single server setups.  Considering the differences across environments and scaling needs, we cannot provide an estimate of server resources beyond single server setups.
It’s possible to scale the solution to multiple event collectors and ELK nodes, but that will require more experience with the technologies involved. However, we plan to publish documentation for scaling LME in the future.

Please see the above blogpost from elastic for discussion on how to scale an elastic stack cluster. 

## Required infrastructure

To begin installing LME, you will need access to the following servers or you will need to create them:

- A client machine (or multiple client machines) you would like to monitor.
- An Ubuntu linux 22.04 server.

We will install our database (Elasticsearch) and dashboard software on this machine. This is all taken care of through Podman containers.

### Minimum Hardware Requirements:
   -  CPU: 2 processor cores, 4+ recommended
   -  MEMORY: 16GB RAM,  (32GB+ recommended by [Elastic](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-hardware-prereq.html)),
   - STORAGE: dedicated 128GB storage for ELK (not including storage for OS and other files)
This is estimated to only support ~17 clients worth of log streaming data per day. Elasticsearch will automatically purge old logs to make space for new ones. We **highly** suggest more storage than 128GB for any enterprise network greater than this.
    
If you need to run LME with less than 16GB of RAM or minimal hardware, please follow our troubleshooting guide to configure Podman quadlets for reduced memory usage. We recommend setting Elasticsearch to an 8GB limit and Kibana to a 4GB limit. You can find the guide [here](/docs/markdown/reference/troubleshooting.md#memory-in-containers-need-more-ramless-ram-usage).
		 
#### Confirm your system meets the minimum hardware requirements:
**CPU**: To check the number of CPUs, run the following command:
```bash
$ lscpu | egrep 'CPU\(s\)'
```
**Memory**: To check your available memory, run this command, look under the "free" column:
```bash
$ free -h 
total        used        free      shared  buff/cache   available
Mem:            31Gi       6.4Gi        22Gi       4.0Mi       2.8Gi        24Gi
Swap:             0B          0B          0B
```

**Storage**: To check available hardware storage, typically the /dev/root will be your main filesystem. The number of gigabytes available is in the Avail column
```bash
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       124G   13G  112G  11% /
```

## Where to install the servers

Servers can be either on premise, in a public cloud, or in a private cloud. It is your choice, but you'll need to consider how to network between the clients and servers.

## What firewall rules are needed?
Please see our cloud documentation for a discussion on firewalls [LME in the Cloud](/docs/markdown/loggging-guidance/cloud.md). 

You must ensure that the client machine you want to monitor can reach the main LME ports as described in the ReadMe [Required Ports section](/README.md#required-ports).