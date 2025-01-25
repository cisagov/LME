# Troubleshooting LME Install
## Installation Troubleshooting
**Make sure to use `-i` to run a login shell with any commands that run as root, so environment variables are set properly** [LINK](https://unix.stackexchange.com/questions/228314/sudo-command-doesnt-source-root-bashrc)

**The services take a while to start give it a few minutes before assuming things are broken**

1. Confirm services are installed: 
```bash
sudo systemctl daemon-reload
sudo systemctl list-unit-files lme\*
```

Debug if necessary. The first step is to check the status of individual services listed above:
```bash
#if something breaks, use these commands to debug:
SERVICE_NAME=lme-elasticsearch.service
sudo -i journalctl -xu $SERVICE_NAME
```

If something is broken, try restarting the services and making sure failed services reset before starting:
```bash
#try resetting failed: 
sudo -i systemctl  reset-failed lme*
sudo -i systemctl  restart lme.service
```

2. Check that containers are running and healthy. This command will also print container names!
```bash
sudo -i podman ps --format "{{.Names}} {{.Status}}"
```  

Example output: 
```shell
lme-elasticsearch Up 19 hours (healthy)
lme-wazuh-manager Up 19 hours
lme-kibana Up 19 hours (healthy)
lme-fleet-server Up 19 hours
lme-elastalert2 Up 17 hours
```
This also prints the names of the containers in the first column of text on the left. You'll want the container names.

We are currently missing health checks for fleet-server and elastalert2, so if those are up they won't show healthy and thats expected. Health checks for these services will be added in a future version.

If a container is missing you can check its logs here: 
```bash
#also try inspecting container logs: 
CONTAINER_NAME=lme-elasticsearch #change this to your container name you want to monitor lme-kibana, etc...
sudo -i podman logs -f $CONTAINER_NAME
```

3. Check if you can connect to Elasticsearch
```bash
#substitute your password below:
curl -k -u elastic:$(sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep elastic | awk '{print $1}') | tr -d '\n') https://localhost:9200
```

Example output:
```json
{
  "name" : "lme-elasticsearch",
  "cluster_name" : "LME",
  "cluster_uuid" : "FOnfbFSWQZ-PD-rU-9w4Mg",
  "version" : {
    "number" : "8.12.2",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "48a287ab9497e852de30327444b0809e55d46466",
    "build_date" : "2024-02-19T10:04:32.774273190Z",
    "build_snapshot" : false,
    "lucene_version" : "9.9.2",
    "minimum_wire_compatibility_version" : "7.17.0",
    "minimum_index_compatibility_version" : "7.0.0"
  },
  "tagline" : "You Know, for Search"
}

```

4. Check if you can connect to Kibana <br/>
You can use a ssh proxy to forward a local port to the remote linux host. To login as the Elastic admin use the username `elastic` and elastics password grabbed from the export password script [here](#grabbing-passwords)
```bash
#connect via ssh if you need to 
ssh -L 8080:localhost:5601 [YOUR-LINUX-SERVER]
#go to browser:
#https://localhost:8080
```

You can also navigate to your browser at the value you set for `IPVAR`: https://IPVAR

## Post-Installation Troubleshooting

Run the following commands to check `/opt/lme/dashboards/elastic/` and `/opt/lme/dashboards/wazuh/` directories if dashboard installation was successful:
```bash
sudo -i 
ls -al /opt/lme/FLEET_SETUP_FINISHED
ls -al /opt/lme/dashboards/elastic/INSTALLED
ls -al /opt/lme/dashboards/wazuh/INSTALLED
```

which should look like the following: 
```bash
root@ubuntu:~# ls -al /opt/lme/FLEET_SETUP_FINISHED
-rw-r--r-- 1 root root 0 Oct 21 18:41 /opt/lme/FLEET_SETUP_FINISHED
root@ubuntu:~# ls -al /opt/lme/dashboards/elastic/INSTALLED
-rw-r--r-- 1 root root 0 Oct 21 18:44 /opt/lme/dashboards/elastic/INSTALLED
root@ubuntu:~# ls -al /opt/lme/dashboards/wazuh/INSTALLED
-rw-r--r-- 1 root root 0 Oct 21 19:01 /opt/lme/dashboards/wazuh/INSTALLED
```
If you don't have these files, something has screwed up, please read the output from ansible, and feel free to file an issue or dicussion. Issues are for bugs, most likely an issue has occured in your post installation due to a specific component in your local installation, please file a discussion unless this is believed to be a bug.

## Logging Issues

### Space issues during install: 
If your system has size constraints and doesn't meet our expected requirements, you could run into issues like this [Getting error with Step 3.2.2 when running the deploy.sh script
](https://github.com/cisagov/LME/issues/19).

You can try this:  [DISK-SPACE-20.04](https://askubuntu.com/questions/1269493/ubuntu-server-20-04-1-lts-not-all-disk-space-was-allocated-during-installation)
```
root@util:# vgdisplay
root@util:# lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
root@util:~# resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```

### Containers restarting/not running: 
Usually If you have issues with containers restarting, check your host or the container itself. Like in the above sample, a wrong password could prevent the Elastic Stack from operating properly. You can check the container logs like so: 
```bash
sudo -i podman ps --format "{{.Names}} {{.Status}}"
```  

```bash
#Using the above name you found, check its logs here. 
sudo -i podman logs -f $CONTAINER_NAME
```
If this doesn’t determine the issue, see below for some common issues you could encounter.

## Container Troubleshooting:

### "dependent containers which must be removed"
sometimes podman doesn't kill containers properly when you stop and start `lme.service`

If you get the below error after inspecting the logs in systemd: 
```bash
#journal: 
journalctl -xeu lme-elasticsearch.service
#OR systemctl
systemctl status lme*
```

ERROR:
```bash
ubuntu lme-elasticsearch[43436]: Error: container bf9cb322d092c13126bd0341a1b9c5e03b475599e6371e82d4d866fb088fc3c4 has dependent containers which must be removed before it: ff7a6b654913838050360a2cea14fa1fdf5be1d542e5420354ddf03b88a1d2c9: container already exists
```

Then you'll need to do the following: 
1. kill the other containers it lists manually
```
sudo -i podman rm  ff7a6b654913838050360a2cea14fa1fdf5be1d542e5420354ddf03b88a1d2c9
sudo -i podman rm  bf9cb322d092c13126bd0341a1b9c5e03b475599e6371e82d4d866fb088fc3c4
```
2. remove other containers that are dead: 
```
sudo -i podman ps -a
sudo podman rm $CONTAINER_ID
```
4. restart the `lme.service`
```
systemctl restart lme.service
```


### Memory in containers (need more RAM//less RAM usage)
If you're on a resource constrained host and need to limit/edit the memory used by the containers add the following into the quadlet file. 

```bash
....
 EnvironmentFile=/opt/lme/lme-environment.env
 Image=localhost/elasticsearch:LME_LATEST
 Network=lme
 PodmanArgs=--memory 8gb --network-alias lme-elasticsearch --health-interval=2s
 PublishPort=9200:9200
 Ulimit=memlock=-1:-1
 Volume=lme_certs:/usr/share/elasticsearch/config/certs
 ....
```
**Notes**
- You don't need to run the commands, but simply change the quadlet file you want to update. If this is before you've installed LME, you can edit the quadlet in the directory you've cloned: `~/LME/quadlet/lme-elasticsearch.container`

- If this is after installation you can edit the quadlet file in `/etc/containers/systemd/lme-elasticsearch.container`
`quadlet/lme-elasticsearch.container` and add the line `--memory Xgb`, with the nubmer of Gigabytes you want to limit for the container.

You can repeat this for any containers you for which you want to limit the memory.

### JVM heap size
If you have alot of RAM (i.e., greater than 128GB) to work with and want your container to consume that RAM (especially in the case of Elasticsearch running under the Java Virtual Machine. Elasticsearch is written in Java). 

So you'll want to edit the JVM options: [ELASTIC_DOCS_JVM](https://www.elastic.co/guide/en/elasticsearch/reference/current/advanced-configuration.html)

By default Elastic only goes up to 31GB of memory usage if you don't set the appropriate variable. If you have a server that has 128 GB and you want to use 64 (the recommendation is half of your total memory) you need to set the ES_JAVA_OPTS variable. To do that you can edit the .container and restart your lme.service like so:

```
sudo nano /opt/lme/quadlet/lme-elasticsearch.container
```

add to the file something like this:

```
Environment=ES_JAVA_OPTS=-Xms64g -Xmx64g
```

restart LME

```
systemctl --user daemon-reload
systemctl --user restart lme.service
```


## Elastic troubleshooting steps

### Manual Dashboard Install
You can now import the dashboards by clicking ‘Management’ -> ‘Stack Management’ -> ‘Saved Objects’. Please follow the steps in Figure 4 below. 

This step should not be required by default. Only use if the installer failed to automatically populate the expected dashboards or if you wish to make use of your own modified version of the supplied visualizations.

Each dashboard and its visualization objects are contained within a NDJSON file (previously JSON) and can be easily imported. The NDJSON files are in [dashboards/](/dashboards).


![Importing Objects](/docs/imgs/import.png)

![Importing Objects](/docs/imgs/import1.png)

![Importing Objects](/docs/imgs/import2.png)

<p align="center">
Figure 4 - Steps to import objects
</p>

### Elastic Specific Troubleshooting

Elastic maintains a series of troubleshooting guides that we suggest you review as part of the standard investigation process if the issue you are experiencing is within the Elastic stack within LME.

These guides can be found [here](https://www.elastic.co/guide/en/elasticsearch/reference/master/troubleshooting.html) and cover a number of common issues.


### Kibana Discover View Showing Wrong Index

If the Discover section of Kibana persistently shows the wrong index by default, check that the winlogbeat index pattern is still set as the default within Kibana. To do this, see the steps below:

Select "Stack Management" from the left-hand menu:

![Check Default Index](/docs/imgs/stack-management.png)

Select "Index Patterns" under Kibana Stack Management:

![Check Default Index](/docs/imgs/index-patterns.png)

Verify that the "Default" label is set next to the ```INDEX_NAME-*``` Index pattern:

![Check Default Index](/docs/imgs/default-winlogbeat.png)

If this Index pattern is not selected as the default, this can be re-done by clicking on the ```INDEX_NAME-*``` pattern and then selecting the following option in the subsequent page:

![Set Default Index](/docs/imgs/default-index-pattern.png)

### Unhealthy Cluster Status

There are several reasons why the cluster's health may be yellow or red, but a common cause is unassigned replica shards. As LME is a single-node instance by default this is means that replicas will never be assigned. However, this issue is commonly caused by built-in indices which do not have the `index.auto_expand_replicas` value correctly set. This will be fixed in a future release of Elastic, but can be temporarily diagnosed and resolved as follows: 

Check the cluster health by running the following request against Elasticsearch (an easy way to do this is to navigate to `Dev Tools` in Kibana under `Management` on the left-hand menu):

```
GET _cluster/health?filter_path=status,*_shards
```

If it shows any unassigned shards, these can be enumerated with the following command:

```
GET _cat/shards?v=true&h=index,shard,prirep,state,node,unassigned.reason&s=state
```

If the `UNASSIGNED` shard is shown as `r` rather than `p` this means it's a replica. In this case tyou can fix the error in the single-node default installation of LME by forcing all indices to have a replica count of 0 using the following request:

```
PUT _settings
{
  "index.number_of_replicas": 1
}
```

If the above solution was unable to resolve your issue, further information on this and general advice on troubleshooting an unhealthy cluster status can be found [here](https://www.elastic.co/guide/en/elasticsearch/reference/master/red-yellow-cluster-status.html).

## FLEET SERVER - ADD AGENT shows missing url for Fleet Server Host

When trying to add Elastic Agent on host server, you may see **Missing URL for Fleet Server host** as shown in screenshot below.

![Check Default Index](/docs/imgs/fleetservermissingurl.png)

This can happen when LME post install steps were run before *lme-fleet-server* displayed status of **Up** when you check podman status.
Do make sure your post installation verification steps are completed.
If post installation verification steps fail, then uninstall and re-install LME is recommended.
Otherwise a simple reboot of the host server or restart of lme-service should fix the problem.


## Start/Stop LME:

### Re-Indexing Errors

For errors encountered when re-indexing existing data as part of an an LME version upgrade please review the Elastic re-indexing documentation for help, available [here](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-reindex.html).

### Illegal Argument Exception While Re-Indexing 

With the correct mapping in place it is not possible to store a string value in any of the fields which represent IP addresses. For example ```source.ip``` or ```destination.ip```. If you see any of these values  represented in your current data as strings, such as ```LOCAL``` you cannot successfully re-index with the correct mapping. In this instance the simplest fix is to modify your existing data to store the relevant fields as valid IP representations using the update_by_query method, documented [here](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-update-by-query.html).

An example of this is shown below, which may need to be modified for the particular field that is causing problems:

```
POST winlogbeat-11.06.2021/_update_by_query
{
  "script": {
    "source": "ctx._source.source.ip = '127.0.0.1'",
    "lang": "painless"
  },
  "query": {
    "match": {
      "source.ip": "LOCAL"
    }
  }
}
```
Note that this will need to be run for each index that contains problematic data before re-indexing can be completed.

### TLS Certificates Expired

For security the self-signed certificates generated for use by LME at install time will only remain valid for a period of two years, which will cause LME to stop functioning once these certificates expire. In this case the certificates can be recreated by following the instructions detailed [here](/docs/markdown/maintenance/certificates.md#regenerating-self-signed-certificates).


## Other Common Errors

### Windows Log with Error Code #2150859027

If you are on Windows 2016 or higher and are getting error code 2150859027, or messages about HTTP URLs not being available in your Windows logs, please review [this guide.](https://support.microsoft.com/en-in/help/4494462/events-not-forwarded-if-the-collector-runs-windows-server-2019-or-2016)

*
### Start/Stop LME:

To Stop LME: 
```
sudo systemctl stop lme.service
```

To Start LME:
```
sudo systemctl restart lme.service
```

## Using API

### Changing elastic Username Password

After installing, if you wish to change the password to the Elastic username you can use the following command: 

**Note**: You will need to run this command with an account that can access /opt/lme. If you can't sudo, the user account will need access to the certs located in the command. 

```
sudo curl -X POST "https://127.0.0.1:9200/_security/user/elastic/_password" -H "Content-Type: application/json" -d'
{
  "password" : "newpassword"
}' --cacert /opt/lme/Chapter\ 3\ Files/certs/root-ca.crt -u elastic:currentpassword
>>>>>>> release-2.0.0
```

## Issues installing Elastic Agent

If you have see the error "Elastic Agent is installed but broken" when trying to install the Elastic Agent add the following flag to your install command:

```
--force
```
