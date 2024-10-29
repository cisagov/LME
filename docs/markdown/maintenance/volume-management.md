# Podman Volumes: The Basics

A Podman volume is a mechanism for storing container data directly on the host machine. When you create a volume and attach it to a container, Podman sets up a dedicated directory on your host system. Any data the container writes to this mounted volume is actually written to this host directory. This means that even if you stop, remove, or replace the container, the data remains intact on your host machine. You can then mount this same volume to a new container, allowing it to access all the previously stored data. This also allows you to have one volume on a host machine that you can mount to multiple containers. For instance our certs volume which is used across all containers.

You will see volumes in our quadlets and they will look something like this:

```bash
/path/on/host/:/path/in/container/
```

On the left of the colon would be a path or file on the host machine that is persisted inside the running container (the path on the right of the colon).

**NOTE: If you do not have a volume assigned to a certain path or file, it will not be persisted. This means restarting a container will blow away any changes you've made on the running container. We've made sure all required files by default are already volumes.**

# Podman Volume Management for LME

Managing disk usage is crucial for maintaining the health and performance of your LME installation. Here's how you can monitor and manage the disk space used by Podman volumes.

### Check Volume Location on Host Machine

You can check the location of your volumes on the host machine by running the following command:

```bash
podman volume inspect <volume_name>
```

To get a list of volumes you can run:

```bash
podman volume ls
```

### Checking Overall Disk Usage

To check the overall disk usage on your system, use the `df` command:

```bash
df -h
```

This will show you the disk usage for all mounted filesystems. Look for the filesystem that contains your home directory (usually `/`).

### Checking Podman Volume Usage

By default Podman volumes are stored in your home directory under `~/.local/share/containers/storage/volumes/`. To check the disk usage of this specific directory:

```bash
sudo du -sh ~/.local/share/containers/storage/volumes/
```

This command will show you the total size of all Podman volumes.

To see a breakdown of individual volume sizes:

```bash
sudo du -sh ~/.local/share/containers/storage/volumes/*
```

### Using Podman's Built-in Tools

Podman provides a built-in command to check disk usage of containers, images, and volumes:

```bash
podman system df -v
```

This command will show you:
- A summary of disk usage by images, containers, and volumes
- A detailed breakdown of each volume's size

### Managing Volume Space

If you find that your volumes are using too much space, consider the following steps:

1. Review the data in large volumes to see if any can be cleaned up or archived.
2. For log volumes (like `lme_wazuh_logs`), consider implementing log rotation if not already in place.
3. For database volumes (like `lme_esdata01`), check if data can be optimized or old indices can be removed. Index management is key for space management with this volume as this will end up your largest volume as elasticsearch collects all your logs and stores them here.
4. Use Podman's prune commands to remove unused volumes:
   ```bash
   podman volume prune
   ```
   **Be careful with this command as it will remove all unused volumes.**

Remember to always backup important data before performing any cleanup operations.

### Viewing Elasticsearch Index Sizes

As discussed earlier lme_esdata01 will store all your logs in indexes. 

To view all your Elasticsearch indexes and their sizes in Kibana:

1. Login to Kibana
2. Click the "hamburger" menu button top left.
3. Scroll down to Stack Management
4. Click "Index Management"
5. Check the option to "Include Hidden Indices"

You should now see all your indexes and their sizes:

![image](https://github.com/user-attachments/assets/f32741af-e77c-4bec-9e3d-268c25d65323)

### Editing Files in Podman Volumes and Bind Mounts

When you edit files that are made available to containers through Podman volumes or bind mounts, these changes are immediately reflected in the running containers. This creates a direct link between files on the host system and within the container's filesystem. In the LME setup, many configuration files use this principle. For example, the Wazuh manager configuration file (ossec.conf) is actually located at `/opt/lme/config/wazuh_cluster/wazuh_manager.conf` on the host and is bind-mounted into the container. 

When you edit this file on the host, the changes are instantly visible to the Wazuh manager process inside the container. You could then restart the wazuh manager container using:

```bash
sudo systemctl restart lme-wazuh-manager.service
```

Now your changes will be implemented into the running wazuh manager container.

# Backup Volumes

Remember that your volumes will be ALL your important data for LME that is persisted. You may want to back this data up to an external hard drive or NAS. Some general steps for doing so:

**Stop all containers before performing a backup**

To external hard drive:
1. Connect external hard drive to your system.
2. Mount the hard drive.
3. Copy volume data from your Podman volume directory to the mounted drive.
4. Safely unmount the drive when finished if desired.

To network storage:
1. Mount/Connect to your network storage.
2. Copy volume data from your Podman volume directory to the network storage.
3. Disconnect/Unmount from the network storage if desired.


Example command you might use to copy all volumes to a mounted drive:

```bash
rsync -av ~/.local/share/containers/storage/volumes/ /mnt/nas/podman_volume_backup/
```

**NOTE: Ensure you are going by your drives documentation for connecting/mounting to an Ubuntu instance.**
