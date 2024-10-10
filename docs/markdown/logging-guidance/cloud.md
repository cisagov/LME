# Logging Made easy in the cloud 

These docs attempt to answer some FAQ and other documentation around Logging Made easy in the cloud. 

## Does LME run in the cloud? 
Yes, Logging Made easy is a simple client-server model, and Logging Made Easy can be deployed in the cloud for cloud infrastructure or in the cloud for on-prem machines.

### Deploying LME in the cloud for on prem systems:
In order for the LME agents to talk to LME in the cloud you'll need to ensure the clients you want to monitor can communicate through: 1) the cloud firewall AND 2) logging Made easy's own server firewall.

![cloud firewall](/docs/imgs/lme-cloud.jpg)

The easiest way is to make sure you can hit these LME server ports from the on-prem client: 
  - WAZUH ([DOCS](https://documentation.wazuh.com/current/user-manual/agent/agent-enrollment/requirements.html)): 1514,1515 
  - Agent ([DOCS](https://www.elastic.co/guide/en/elastic-stack/current/installing-stack-demo-self.html#install-stack-self-elastic-agent)): 8220 

You'll need to make sure the Cloud firewall is setup to allow those ports. On azure, this is a NSG rule you'll need to set for the LME virtual machine. 

Then on LME, you'll want to make sure you have either the firewall disabled (if you're using hte cloud firewall as the main firewall):
```
lme-user@ubuntu:~$ sudo ufw status
Status: inactive
```
or that you have the firewall rules enabled:
```
lme-user@ubuntu:~$ sudo ufw status
Status: active

To                         Action      From
--                         ------      ----
1514                       ALLOW       Anywhere
1515                       ALLOW       Anywhere
22                         ALLOW       Anywhere
8220                       ALLOW       Anywhere
1514 (v6)                  ALLOW       Anywhere (v6)
1515 (v6)                  ALLOW       Anywhere (v6)
22 (v6)                    ALLOW       Anywhere (v6)
8220 (v6)                  ALLOW       Anywhere (v6)
```

### Deploying LME for cloud infrastructure: 

Every cloud setup is different, but as long as the LME server is on the same network and able to talk to the machines you want to monitor everything should be good to go.
