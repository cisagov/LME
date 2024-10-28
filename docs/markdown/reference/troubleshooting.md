# Troubleshooting LME Install

## Logging Issues

### Space issues during install: 
If there are size constraints on your system and your system doesn't meet our expected requirements, you could run into issues like this [ISSUE](https://github.com/cisagov/LME/issues/19).

You can try this:  [DISK-SPACE-20.04](https://askubuntu.com/questions/1269493/ubuntu-server-20-04-1-lts-not-all-disk-space-was-allocated-during-installation)
```
root@util:# vgdisplay
root@util:# lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
root@util:~# resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```

### Containers restarting/not running: 
Usually if you have issues with containers restarting there is probably something wrong with your host or the container itself. Like in the above sample, a wrong password could be preventing the Elastic Stack from operating properly. You can check the container logs like so: 
```bash
sudo -i podman ps --format "{{.Names}} {{.Status}}"
```  

```bash
#Using the above name you found, check its logs here. 
sudo -i podman logs -f $CONTAINER_NAME
```
Hopefully that is enough to determine the issue, but below we have some common issues you could encounter: 

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


### Memory in containers (need more ram//less ram usage)
If you're on a resource constrained host and need to limit/edit the memory used by the containers add the following into the quadlet file. 

You don't need to run the commands, but simply change the quadlet file you want to update. If this is before you've installed LME, you can edit the quadlet in the directory you've cloned: `~/LME/quadlet/lme-elasticsearch.container`

If this is after installation you can edit the quadlet file in `/etc/containers/systemd/lme-elasticsearch.container`

`quadlet/lme-elasticsearch.container` and add the line `--memory Xgb`, with the nubmer of Gigabytes you want to limit for the container.

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

You can repeat this for any containers you for which you want to limit the memory.

### JVM heap size
It may be that you have alot of ram to work with and want your container to consume that RAM (especially in the case of elasticsearch running under the Java Virtual Machine. Elasticsearch is written in Java). 

So you'll want to edit the JVM options: [ELASTIC_DOCS_JVM](https://www.elastic.co/guide/en/elasticsearch/reference/current/advanced-configuration.html)

By default elastic only goes up to 31GB of memory usage if you don't set the appropriate variable. If you have a server that has 128 GB and you want to use 64 (the recommendation is half of your total memory) you need to set the ES_JAVA_OPTS variable. To do that you can edit the .container and restart your lme.service like so:

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
This step should not be required by default, and should only be used if the installer has failed to automatically populate the expected dashboards or if you wish to make use of your own modified version of the supplied visualizations.

Each dashboard and its visualization objects is contained within a NDJSON file (previously JSON) and can be easily imported

You can now import the dashboards by clicking ‘Management’ -> ‘Stack Management’ -> ‘Saved Objects’. Please follow the steps in Figure 4, and the NDJSON files are located in [dashboards/](/dashboards).


![Importing Objects](/docs/imgs/import.png)

![Importing Objects](/docs/imgs/import1.png)

![Importing Objects](/docs/imgs/import2.png)

<p align="center">
Figure 4 - Steps to import objects
</p>

### Elastic Specific Troubleshooting

Elastic maintain a series of troubleshooting guides which should be consulted as part of the standard investigation process if the issue you are experiencing is within the Elastic stack within LME.

These guides can be found [here](https://www.elastic.co/guide/en/elasticsearch/reference/master/troubleshooting.html) and cover a number of common issues which may be experienced.


### Kibana Discover View Showing Wrong Index

If the Discover section of Kibana is persistently showing the wrong index by default it is worth checking that the winlogbeat index pattern is still set as the default within Kibana. This can be done using the steps below:

Select "Stack Management" from the left hand menu:

![Check Default Index](/docs/imgs/stack-management.png)

Select "Index Patterns" under Kibana Stack Management:

![Check Default Index](/docs/imgs/index-patterns.png)

Verify that the "Default" label is set next to the ```INDEX_NAME-*``` Index pattern:

![Check Default Index](/docs/imgs/default-winlogbeat.png)

If this Index pattern is not selected as the default, this can be re-done by clicking on the ```INDEX_NAME-*``` pattern and then selecting the following option in the subsequent page:

![Set Default Index](/docs/imgs/default-index-pattern.png)

### Unhealthy Cluster Status

There are a number of reasons why the cluster's health may be yellow or red, but a common cause is unassigned replica shards. As LME is a single-node instance by default this is means that replicas will never be assigned, but this issue is commonly caused by built-in indices which do not have the `index.auto_expand_replicas` value correctly set. This will be fixed in a future release of Elastic, but can be temporarily diagnosed and resolved as follows: 

Check the cluster health by running the following request against Elasticsearch (an easy way to do this is to navigate to `Dev Tools` in Kibana under `Management` on the left-hand menu):

```
GET _cluster/health?filter_path=status,*_shards
```

If it shows any unassigned shards, these can be enumerated with the following command:

```
GET _cat/shards?v=true&h=index,shard,prirep,state,node,unassigned.reason&s=state
```

If the `UNASSIGNED` shard is shown as `r` rather than `p` this means it's a replica. In this case the error can be safely fixed in the single-node default installation of LME by forcing all indices to have a replica count of 0 using the following request:

```
PUT _settings
{
  "index.number_of_replicas": 1
}
```

Further information on this and general advice on troubleshooting an unhealthy cluster status can be found [here](https://www.elastic.co/guide/en/elasticsearch/reference/master/red-yellow-cluster-status.html), if the above solution was unable to resolve your issue.

## Start/Stop LME:

### Re-Indexing Errors

For errors encountered when re-indexing existing data as part of an an LME version upgrade please review the Elastic re-indexing documentation for help, available [here](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-reindex.html).

### Illegal Argument Exception While Re-Indexing 

With the correct mapping in place it is not possible to store a string value in any of the fields which represent IP addresses, for example ```source.ip``` or ```destination.ip```. If any of these values are represented in your current data as strings, such as ```LOCAL``` it will not be possible to successfully re-index with the correct mapping. In this instance the simplest fix is to modify your existing data to store the relevant fields as valid IP representations using the update_by_query method, documented [here](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-update-by-query.html).

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

If you are on Windows 2016 or higher and are getting error code 2150859027, or messages about HTTP URLs not being available in your Windows logs, we suggest looking at [this guide.](https://support.microsoft.com/en-in/help/4494462/events-not-forwarded-if-the-collector-runs-windows-server-2019-or-2016)

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

After doing an install if you wish to change the password to the elastic username you can use the following command: 

NOTE: You will need to run this command with an account that can access /opt/lme. If you can't sudo the user account will at least need to be able to access the certs located in the command. 

```
sudo curl -X POST "https://127.0.0.1:9200/_security/user/elastic/_password" -H "Content-Type: application/json" -d'
{
  "password" : "newpassword"
}' --cacert /opt/lme/Chapter\ 3\ Files/certs/root-ca.crt -u elastic:currentpassword
>>>>>>> release-2.0.0
```

## Issues installing Elastic Agent

If you have the error "Elastic Agent is installed but broken" when trying to install the elastic agent add the following flag to your install command:

```
--force
```
