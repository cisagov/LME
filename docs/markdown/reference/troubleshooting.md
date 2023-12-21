# Troubleshooting LME Install

## Troubleshooting Diagram

Below is a diagram of the LME architecture with labels referring to possible issues at that specific location. Refer to the chart below for protocol information, process information, log file locations, and common issues at each point in LME.

You can also find more detailed troubleshooting steps for each chapter after the chart.

![Troubleshooting overview](/docs/imgs/troubleshooting-overview.jpg)
<p align="center">  
Figure 1: Troubleshooting overview diagram
</p>


| Diagram Ref| Protocol information | Process Information | Log file location | Common issues |
| :---: |-------------| -----| ---- | ---------------- |
| a | Outbound WinRM using TCP 5985 Link is HTTP, underlying data is authenticated and encrypted with Kerberos. </br></br> See [this Microsoft article](https://docs.microsoft.com/en-us/windows/security/threat-protection/use-windows-event-forwarding-to-assist-in-intrusion-detection) for more information | On the Windows client, Press Windows key + R. Then type 'services.msc' to access services on this machine. You should have: </br></br> ‘Windows Remote Management (WS-Management)’ </br> and </br> ‘Windows Event Log’ </br></br> Both of these should be set to automatically start and be running. WinRM is started via the GPO that is applied to clients. | Open Event viewer on Windows Client. Expand ‘Applications and Services Log’->’Microsoft’->’Windows’->’Eventlog-ForwardingPlugin’->Operational | “The WinRM client cannot process the request because the server name cannot be resolved.” </br> This is due to network issues (VPN not up, not on local LAN) between client and the Event Collector.|
| b | Inbound WinRM TCP 5985 | On the Windows Event Collector, Press Windows key + R. Then type 'services.msc' to access services on this machine. You should have:  </br></br> ‘Windows Event Collector’ </br></br> This should be set to automatic start and running. It is enabled with the GPO for the Windows Event Collector. | Open Event viewer on Windows Event Collector. </br></br> Expand ‘Applications and Services Log’->’Microsoft’->’Windows’->’EventCollector’->Operational </br></br> Also, in Event Viewer check the subscription is active and clients are sending in logs. Click on ‘Subscriptions’, then right click on ‘lme’ and ‘Runtime Status’. This will show total and active computers connected. | Restarting the Windows Event Collector machine can sometimes get clients to connect. |
| c | Outbound TCP 5044. </br></br> Lumberjack protocol using TLS mutual authentication. Certificates generated as part of the install, and downloaded as a ZIP from the Linux server. | On the Windows Event Collector, Press Windows key + R. Then type 'services.msc' to access services on this machine. You should have: </br></br> ‘winlogbeat’. </br></br> It should be set to automatically start and is running. | %programdata%\winlogbeat\logs\winlogbeat | TBC |
| d | Inbound TCP 5044. </br> </br> Lumberjack protocol using TLS mutual authentication. Certificates generated as part of the install. | On the Linux server type ‘sudo docker stack ps lme’, and check that lme_logstash, lme_kibana and lme_elasticsearch all have a **current status** of running.  | On the Linux server type: </br> </br> ‘sudo docker service logs -f lme_logstash’ | TBC |

## Chapter 1 - Setting up Windows Event Forwarding

### Installing Group Policy Management Tools

If you receive the error `Windows cannot find 'gpmc.msc'`, you need to install the optional feature `Group Policy Management Tools`.

  - For Windows Server, follow Microsoft's instructions [here](https://learn.microsoft.com/en-us/azure/active-directory-domain-services/manage-group-policy#install-group-policy-management-tools). In short, you need to add the "Group Policy Management" Feature from the "Add Roles and Features" menu in Server Manager.
  - For Windows 10/11, open the "Run" dialog box by pressing Windows key + R. Run the command `ms-settings:optionalfeatures` to open Windows Optional Features in Settings. Select "Add a Feature," then scroll down until you find `RSAT: Group Policy Management Tools`. Check the box next to it and select install.

    ![add optional feature](/docs/imgs/gpo_pics/optional_features.png)
    <p align="center">
    Figure 2: Add a feature
    </p>

    ![install gpmc.msc](/docs/imgs/gpo_pics/rsat_gpmc_optional_features.png)
    <p align="center">
    Figure 3: Install RSAT: Group Policy Management Tools
    </p>

- Note: You only need `gpmc.msc` installed on one machine to manage the others. For example, you can install it only on the Domain Controller and modify the Group Policy from that machine.

### Installing Active Directory Domain Services

If you receive the error `dsa.msc` cannot be found, you will need to install `Active Directoy Domain Services`. The process is nearly identical to the above section [Installing Group Policy Management Tools](#installing-group-policy-management-tools), save for the following exceptions:

  - For Windows Server, the feature is located under "Remote Server Administration Tools". Expand by pressing the arrow on the left and check the box next to `Role Administration Tools`. The other nested features should be selected as well.
  - For Windows 10/11, the Optional Feature to install is called `RSAT: Active Directory Domain Services and Lightweight Directory Services Tools`.

## Chapter 2 - Installing Sysmon

If you are having trouble not seeing Sysmon logs in the client's Event Viewer or not seeing forwarded logs on the WEC, first try restarting all of your systems and running `gpupdate /force` on the domain controller and clients.

### No Logs Forwarded from Clients

When diagnosing issues in installing Sysmon on the clients using Group Policy, the first place to check is `Task Scheduler` on one of the clients. Look for `LME-Sysmon-Task` listed under "Active Tasks." Based on whether or not the task is listed, different troubleshooting steps will prove useful:

- If the task isn't listed either the GPO hasn't been applied or the Task isn't properly configured. See both [Step 1](#1-the-gpo-hasnt-applied) and [Step 2](#2-the-task-is-improperly-configured).
- If the task *is* listed, the GPO has been applied, but either the Task has yet to run or it isn't properly configured. See [Step 2](#2-the-task-is-improperly-configured) and [Step 3](#3-the-task-runs-but-sysmon-is-not-installed).

#### 1. The GPO hasn't applied

By default, Windows will update group policy settings only every 90 minutes. You can manually trigger a group policy update by running `gpupdate /force` in a Command Prompt window on the Domain Controller and the client.

If after ensuring that group policy is updated on the client the client is still missing `LME-Sysmon-Task`, continue to [Step 2](#2-the-task-is-improperly-configured).

#### 2. The task is improperly configured

Windows Tasks are a fickle beast. In order for a task to trigger for the first time, **the trigger time must be set at some time in the future**, even if the Task is set to run repeatedly at a given interval.

#### 3. The task runs, but Sysmon is not installed

If you don't see `sysmon64` listed in `services.msc`, it's likely the install script failed somehow. Double check that the files are organized correctly according to the diagram in the [Chapter 2 checklist](/docs/markdown/chapter2.md#chapter-2---checklist). 

## Chapter 3 - Installing the ELK Stack and Retrieving Logs

### Events not forwarded to Kibana
The `winlogbeat` service installed in [section 3.3](/docs/markdown/chapter3/chapter3.md#33-configuring-winlogbeat-on-windows-event-collector-server) is responsible for sending events from the collector to Kibana.  Confirm the `winlogbeat` service is running and check the log file (`C:\ProgramData\winlogbeat\logs`) for errors.

By default the `ForwardedEvents` maximum log size is around 20MB so events will be lost if the `winlogbeat` service stops.  Consider increasing the size of the `ForwardedEvents` log file to help reduce log loss in this scenario.  Historical logs are sent once the `winlogbeat` service starts.

* Open Microsoft Event View (`eventvwr`)
* Expand _Windows Logs_ and right click _Forwarded Events_
* Click _properties_
* Adjust \_Maximum log size (KB)_ to a higher value.  Note that the system will automatically adjust the size to the nearest multiple of 64KB.

![Adjusting the log size](/docs/imgs/AdjustForwardedEventsLogSize.png)

### Events not forwarding from Domain Controllers
Please be aware that Logging Made Easy does not currently support logging Domain Controllers, and the log volumes may be significant from servers with this role.  If you wish to proceed forwarding logs from your Domain Controllers please be aware you do this at your own risk!  Monitoring such servers has not been tested and may have unintended side effects.




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
```
#TO list the name of the container
sudo docker ps --format "{{.Names}}"

#Using the above name you found, check its logs here. 
sudo docker logs -f [CONTAINER_NAME]
```
Hopefully that is enough to determine the issue, but below we have some common issues you could encounter: 

#### Directory Permission issues
If you encounter errors like [this](https://github.com/cisagov/LME/issues/15) in the container logs, probably your host ownership or permissions for mounted files, don't match what the container expects them to be. In this case the `/usr/share/elasticsearch/backups` which is mapped from `/opt/lme/backups` on the host. 
You can see this in the [docker-compose-stack.yml](https://github.com/cisagov/LME/blob/main/Chapter%203%20Files/docker-compose-stack.yml) file: 
```
╰─$ cat Chapter\ 3\ Files/docker-compose-stack.yml | grep -i volume -A 5
    volumes:
      - type: volume
        source: esdata
        target: /usr/share/elasticsearch/data
      - type: bind
        source: /opt/lme/backups
        target: /usr/share/elasticsearch/backups
```

To fix this you can change the permissions to what the container expects: 
```
sudo chown -R 1000:1000 /opt/lme/backups
```
The user id in the container is 1000, so by setting the proper owner we fix the directory permission issue.   
We know this by investigating the backing docker container image for elasticsearch [LINK](https://github.com/elastic/elasticsearch/blob/61d59b31a27448e3d7d28907717b1b8c23f52f3e/distribution/docker/src/docker/Dockerfile#L185) [GITHUB](https://github.com/elastic/elasticsearch/blob/main/distribution/docker/src/docker/Dockerfile)


####  deploy.sh stalls on: waiting for elasticsearch to connect
This was a bug that was fixed in the current iteration of deploy.sh. This occurs if the `elastic` user password was already set in a previous deployment of LME. The easiest fix for this is to delete your old LME volumes as that will clear out any old settings that would be preventing install.
```
#DONT RUN THIS IF YOU HAVE DATA YOU WANT TO PRESERVE!!
sudo docker volume rm lme_esdata
sudo docker volume rm lme_logstashdata
```

However most users will probably want to preserve their data, so using the following method you can reset the user password for the built-in elastic user.  
Run the following commands to reset your user password to a known password  
```
#grab the name:
sudo docker ps --format "{{.Names}}" | grep -i elastic
#go into elasticsearch container
sudo docker exec -it  ${NAME_HERE} /bin/bash
#ignore cert issues with our self signed cert:
echo "xpack.security.http.ssl.verification_mode: certificate" >> config/elasticsearch.yml
#reset in the container:
#add a -f if needed
elasticsearch-reset-password -v -u elastic -i --url https://localhost:9200
```
If the elasticsearch-reset-password is not available in your version of elasticsearch, you may be able to try recreating the container with a newer version of LME and running the same above steps. We have not tested this last suggestion, so attempting this last step won't be supported, but is worth a try if none of the above works.

### Elasticsearch fails to boot on Linux server
Sometimes environmental differences can make the installation process get screwed up [ISSUE](https://github.com/cisagov/LME/issues/21). If you have the luxury, you could perform a full reinstall: 

If you are unable to access https://<LINUX_SERVER_IP/HOSTNAME>, this is most likely because the elasticsearch service fails to run on the Linux server. To perform a full reinstall: 
```
cd /opt/lme/Chapter\ 3\ Files/
sudo ./deploy.sh uninstall
#delete everything:
rm -r /opt/lme
#Reclone the LME repository into /opt/lme/: 
git clone git@github.com:cisagov/LME.git /opt/lme/
#Navigate back to Chapter 3 Files: 
cd /opt/lme/Chapter\ 3\ Files/
sudo ./deploy.sh install
#Save credentials, then continue with Chapter 3 installation
```
Optionally you could uninstall docker entirely and reinstall it from the deploy.sh script. If you do end up removing Docker this link could be helpful: https://askubuntu.com/a/1021506.

## Chapter 4 and Beyond

### Manual Dashboard Install
This step should not be required by default, and should only be used if the installer has failed to automatically populate the expected dashboards or if you wish to make use of your own modified version of the supplied visualizations.

Each dashboard and its visualization objects is contained within a NDJSON file (previously JSON) and can be easily imported

You can now import the dashboards by clicking ‘Management’ -> ‘Stack Management’ -> ‘Saved Objects’. Please follow the steps in Figure 4, and the NDJSON files are located in [Chapter 4 Files\dashboards](/Chapter%204%20Files/dashboards).


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

Verify that the "Default" label is set next to the ```winlogbeat-*``` Index pattern:

![Check Default Index](/docs/imgs/default-winlogbeat.png)

If this Index pattern is not selected as the default, this can be re-done by clicking on the ```winlogbeat-*``` pattern and then selecting the following option in the subsequent page:

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

### Dashboard Update Script Failing

If you encounter an error when the dashboards are updated using the dashboard update script, either manually or as part of automatic updates, this may mean that your current version of Elastic is too old to support the minimum functionality required for the new dashboard versions. Ensure that the latest supported version of the Elastic stack is in use with the following command:
```
cd /opt/lme/Chapter\ 1\ Files/
sudo ./deploy.sh update
```
Then upload the latest dashboards by following one of the methods described [here](/docs/markdown/chapter4.md#411-import-initial-dashboards).


## Other Common Errors

### Windows Log with Error Code #2150859027

If you are on Windows 2016 or higher and are getting error code 2150859027, or messages about HTTP URLs not being available in your Windows logs, we suggest looking at [this guide.](https://support.microsoft.com/en-in/help/4494462/events-not-forwarded-if-the-collector-runs-windows-server-2019-or-2016)

*
### Start/Stop LME:
LME currently runs using the docker stack deployment architecture. 

To Stop LME: 
```
sudo docker stack rm lme
```

To Start LME:
```
sudo docker stack deploy lme --compose-file /opt/lme/Chapter\ 3\ Files/docker-compose-stack-live.yml
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
```

Replace 'currentpassword' with your current password and 'newpassword' with the password you would like to change it to. 

Utilize environment variables in place of currentpassword and newpassword to avoid saving your password to console history. If not we recommend you clear your history after changing the password with ```history -c```

## Index Management

If you are having issues with your hard disk filling up too fast you can use these steps to delete logs earlier than your current settings.

1. **Log in to Elastic**
   - Access the Elastic platform and log in with your credentials.

2. **Navigate to Management Section**
   - In the main menu, scroll down to "Management."

3. **Access Stack Management**
   - Within the Management section, select "Stack Management."

4. **Select Index Lifecycle Policies**
   - In Stack Management, find and choose "Index Lifecycle Policies."

5. **Choose the Relevant ILM Policy**
   - From the list, select `lme_ilm_policy` for editing.

6. **Adjust the Hot Phase Settings**
   - Navigate to the 'Hot Phase' section.
   - Expand 'Advanced settings'.
   - Uncheck "Use recommended defaults."
   - Change the "Maximum age" setting to match your desired delete phase duration.

     > **Note:** Aligning the maximum age in the hot phase with the delete phase ensures consistency in data retention.

7. **Adjust the Delete Phase Settings**
   - Scroll to the 'Delete Phase' section.
   - Find and adjust the "Move data into phase when:" setting.
   - Ensure the delete phase duration matches the maximum age set in the hot phase.

     > **Note:** This setting determines the deletion timing of your logs. Ensure to back up necessary data before changes.

8. **Save Changes**
   - Save the adjustments you've made.

9. **Verify the Changes**
   - Review and ensure that the changes are functioning as intended. Indices may not delete immediately - allow time for job to run.

10. **Document the Changes**
    - Record the modifications for future reference.

You can also manually delete an index from the GUI under Management > Index Managment or by using the following command: 

```
curl -X DELETE "https://127.0.0.1:9200/your_index_name" -H "Content-Type: application/json" --cacert /opt/lme/Chapter\ 3\ Files/certs/root-ca.crt -u elastic:yourpassword
```
> **Note:**    Ensure this is not your current winlogbeat index in use. You should only delete indices that have already rolled over. i.e. if you have index winlogbeat-00001 and winlogbeat-00002 do NOT delete winlogbeat-00002.

If you only have one index you can manually force a rollover with the following command: 

```
curl -X POST "https://127.0.0.1:9200/winlogbeat-alias/_rollover" -H "Content-Type: application/json" --cacert /opt/lme/Chapter\ 3\ Files/certs/root-ca.crt -u elastic:yourpassword
```

This will rollover winlogbeat-00001 and create winlogbeat-00002. You can now manually delete 00001. 

