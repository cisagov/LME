# Logging Made Easy in the cloud 

These docs attempt to answer some FAQ and other documentation around Logging Made easy in the cloud. 

## Does LME run in the cloud? 
Yes, Logging Made easy is a simple client-server model, and Logging Made Easy can be deployed in the cloud for cloud infrastructure or in the cloud for on-prem machines.


### Deploying LME in the cloud for on prem systems:
In order for the LME agents to talk to LME in the cloud you'll need to ensure the clients you want to monitor can communicate through: 1) the cloud firewall AND 2) logging Made easy's own server firewall.

![cloud firewall](/docs/imgs/lme-cloud.jpg)

The easiest way is to make sure you can hit these LME server ports from the on-prem client: 
  - WAZUH ([DOCS](https://documentation.wazuh.com/current/user-manual/agent/agent-enrollment/requirements.html)): 1514,1515 
  - Agent ([DOCS](https://www.elastic.co/guide/en/elastic-stack/current/installing-stack-demo-self.html#install-stack-self-elastic-agent)): 8220 (fleet commands), 9200 (input to elasticsearch)

You'll need to make sure your Cloud firewall is setup to allow those ports. On azure, network security groups (NSG) run a firewall on your virtual machines network interfaces.  You'll need to update your LME virtual machine's rules to allow inbound connections on the agent ports. Azure has a detailed guide for how to add security rules [here](https://learn.microsoft.com/en-us/azure/virtual-network/manage-network-security-group?tabs=network-security-group-portal#create-a-security-rule). 

##### ***We highly suggest you do not open ANY PORT globally and restrict it based on your clients ip address or your client's subnets.****

Then on LME, you'll want to make sure you have either the firewall disabled (if you're using the cloud firewall as the main firewall):
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

You can add the above ports to ufw via the following command: 
```
sudo ufw allow 1514
sudo ufw allow 1515
sudo ufw allow 8220
sudo ufw allow 9200
```
If you want to use the wazuh api, you'll also need to setup port 55000 to be allowed in:
```
sudo ufw allow 55000
```

In addition, you'll need to setup rules to forward traffic to the container network and allow traffic to run on the container network:
```
ufw route allow in on eth0 out on podman1 to any port 443,1514,1515,5601,8220,9200 proto tcp
ufw route allow in on podman1
```
Theres a helpful stackoverflow article on why: [LINK](https://stackoverflow.com/questions/70870689/configure-ufw-for-podman-on-port-443)
Your `podman1` interface name maybe differently, check the output of your network interfaces here and see if its also called podman1: 
```
sudo -i podman network inspect lme | jq 'map(select(.name == "lme")) | map(.network_interface) | .[]'
```

Your rules can be dumped and shown like so: 
```
root@ubuntu:~# ufw show added
Added user rules (see 'ufw status' for running firewall):
ufw allow 22
ufw allow 1514
ufw allow 1515
ufw allow 8220
ufw route allow in on eth0 out on podman1 to any port 443,1514,1515,5601,8220,9200 proto tcp
ufw allow 443
ufw allow in on podman1
ufw allow 9200
root@ubuntu:~#
```

### Deploying LME for cloud infrastructure: 

Every cloud setup is different, but as long as the LME server is on the same network and able to talk to the machines you want to monitor everything should be good to go.

## Other firewall rules
You may also want to access kibana from outside the cloud as well. You'll want to make sure you either allow port `5601` or port `443` inbound from the cloud firewall AND virtual machine firewall. 

```
root@ubuntu:/opt/lme# sudo ufw allow 443
Rule added
Rule added (v6)
```

```
root@ubuntu:/opt/lme# sudo ufw status
Status: active

To                         Action      From
--                         ------      ----
22                         ALLOW       Anywhere
1514                       ALLOW       Anywhere
1515                       ALLOW       Anywhere
8220                       ALLOW       Anywhere
443                        ALLOW       Anywhere
22 (v6)                    ALLOW       Anywhere (v6)
1514 (v6)                  ALLOW       Anywhere (v6)
1515 (v6)                  ALLOW       Anywhere (v6)
8220 (v6)                  ALLOW       Anywhere (v6)
443 (v6)                   ALLOW       Anywhere (v6)
```

### Don't lock yourself out AND Enabling the firewall
 
You also probably don't want to lock yourself out of ssh, so make sure to enable port 22!
```
sudo ufw allow 22
```

Enable ufw:
```
sudo ufw enable
```


