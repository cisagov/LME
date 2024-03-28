# Backing up LME Logs

You back up logs using the built-in Elastic facilities. Out of the box,
Elasticsearch supports backing up to filesystems, and this is the only approach LME supports. Other backup destinations are supported but these require
separate plugins, and LME does not not support them.

## Approach

You create backups using Elasticsearch snapshots. The initial snapshot will
contain all of the current logs but subsequent backups will onlyYou  contain changes
since the last snapshot was taken. It is possible to take regular
backups without a significant effect on the system's performance and without
consuming large amounts of disk space.

## Setting up a backup schedule

### Create a filesystem repository

The LME installation creates a bind mount in Docker that maps to the
`/opt/lme/backups` directory on the host system.

The amount of disk space on the host system determines the LME log retention period. We **strongly** recommend thatyou mount an external drive at the `/opt/lme/backups` location so that both disk space is conserved
and to ensure that backups exist on a separate drive. Backups use a large volume of disk space, and if the storage volume provided is not suitable to store these logs without running out of space backups may cease to function, or LME may stop working altogether if all available disk space on the primary host is consumed.

Once you have mounted the external drive on the host, you will need to ensure the ownership of the `/opt/lme/backups` folder is correct, to ensure the elasticsearch user can write the backups correctly. By default the root user will likely be the owner of this folder, and you will need to change this so that the user you created during the operating system's installation is the owner. To do this use the following command:

```
sudo chown -R 1000 /opt/lme/backups/
```

**This will allow the user you configured during the system's installation to write to this location, so ensure that this user is appropriately secured.**

You will then need to create a repository for Elastic to use, which can be done through the Kibana interface.

First navigate to the "Snapshot and Restore" page under the `Stack Management` tab:

![Snapshot and Restore](/docs/imgs/backup_pics/snapshot_and_restore.png)

Then create a repository by clicking the "Register a repository" button and
filling in the following screens:

![Repository one](/docs/imgs/backup_pics/repository_1.png)

In the above picture, the repository has been named "LME-backups" but you can
select any other name as appropriate. The "Shared file system" repository type
should be selected.

On the next screen, the file system location should be set to
`/usr/share/elasticsearch/backups`. The other fields can be left with the default values, or modified as required.

![Repository two](/docs/imgs/backup_pics/repository_2.png)

The repository will be created and will show in the list on the `Stack  Management`
screen:

![Repository three](/docs/imgs/backup_pics/repository_3.png)

### Create a snapshot schedule policy

You then need to create a policy for the backups. Select the "policies" tab and
then click the "Create a policy" button:

![Policy One](/docs/imgs/backup_pics/policy_1.png)

On the next screen, pick a name for your new policy ("lme-snapshots" in this
example). For the snapshot name the value `<lme-daily-{now/d}>` will create
files with the prefix `lme-daily` and with the current date as a suffix. Make
sure that you select your new repository, and then configure a schedule in line with
your backup policy. Elasticsearch uses incremental snapshots for its backup,
and so only the previous day's logs will need to be snapshotted, which will help
minimize the performance impact.

![Policy Two](/docs/imgs/backup_pics/policy_2.png)

Leave the next screen with its default values and click "Next":

![Policy Three](/docs/imgs/backup_pics/policy_3.png)

If desired, configure the next screen with the relevant retention settings based on your available disk space and your backup policy and then click "Next":

![Policy Four](/docs/imgs/backup_pics/policy_4.png)

Review the new policy and click "Create policy".

![Policy Five](/docs/imgs/backup_pics/policy_5.png)

If you want to test the new policy or want to create the initial snapshot, you can
select the "Run now" option for the policy on the polices tab:

![Policy Six](/docs/imgs/backup_pics/policy_6.png)

## Backup management

Snapshots will now be periodically written to the drive mounted at
`/opt/lme/backups`. It is recommended that these are managed in line with your
current backup policies and processes.

# Restoring a backup:

These steps will walk you through restoring backups assuming you have a new elasticsearch instance with old log backups from a previous LME.  
If you wish to restore a backup follow the below steps: 

1. Navigate to Stack-Management -> Snapshot and Restore -> Repositories:  
![NavBar](/docs/imgs/nav-bar.png)  
![snaprestore](/docs/imgs/snap-restore.png)  
2. Register a new repository following the same directions as above to reference the mounted host directory at the container path. [link](#Create-a-filesystem-repository)
3.  Verify the Repository is connected by hitting the `Verify Repository` button. You should see a similar prompt circled in blue below:  
![verify](/docs/imgs/verify.png)
4. Under snapshots you should now see your old lme backup in the `LMEBackups` Repository:   
![restore](/docs/imgs/restore.png)
5. Restore using the logistics tab -> settings -> Review  
![logistics](/docs/imgs/logistics.png)
6. If you encounter the below error you will need to fiddle with the index settings to successfully restore your backups. You can either: (1) rename the indexes on the `logistics` page, OR (2) close your current indexes   that have name conflicts. Follow below for both options  
![error](/docs/imgs/error.png)

## Rename the indexes on import:
1. usually all you'll want is the winlogbeat data, we can rename that like below. Make sure you uncheck `restore aliases` otherwise elastic will think you're restoring multiple indices (the old and the new renamed one).  
![restore-details](/docs/imgs/restore-details.png)
2. Restore just like in the above directions
   

## Close current indexes to enable importing the old:
1. Navigate to `Stack-Management -> Data -> Index  Management` on the navbar.  
2. close the conflicting index that currently exists:   
![close](/docs/imgs/close-index.png)

