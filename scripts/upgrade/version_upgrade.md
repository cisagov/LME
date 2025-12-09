# LME Version Upgrade Guide

This document explains the versioning system for LME and how to perform upgrades between versions.

## Versioning System

Starting with LME 2.1.0, we have implemented a versioning system to track LME releases. The version follows semantic versioning:

- **Major version**: Significant changes to architecture or major feature additions
- **Minor version**: New features with backward compatibility
- **Patch version**: Bug fixes and small improvements

The version is stored in the `lme-environment.env` file as `LME_VERSION`.

## Determining Your Current Version

To determine your current LME version and if an upgrade is needed, run:

```bash
sudo ~/LME/scripts/upgrade/detect_version.sh
```

This script will:
1. Check if the LME_VERSION environment variable exists
2. If it doesn't exist (older installations), add it
3. Compare your version to the latest available version
4. Inform you if an upgrade is recommended

## Performing an Upgrade

### Prerequisites

Before upgrading:
1. Back up any critical data (The upgrade has a backup built in. Just type the full word "yes" when it asks)
2. Ensure you have sufficient disk space 
3. Check system requirements for the new version

Backups are stored in the same place as your current containers. This assumes that the drive with the conainers is your largest drive/volume. 
You will need double the space free as used (less than 50%) if you want to make a backup. 
There is no check for if you have sufficient space. So check this manually with 
```
df -h
```
The default location for containers is /var/lib/containers/storage. 

You can find your volume directory in /etc/containers/storage.conf. 
```
cat /etc/containers/storage.conf
```

The `graphroot = "/var/lib/containers/storage"` line tells you where they are. 

### Upgrade Process

To upgrade LME to the latest version:

1. Move any downloads that you might have in the home directory
   ```bash
   mv ~/LME ~/LME_OLD
   ```
1. Download the latest release:
   ```bash
   curl -s https://api.github.com/repos/cisagov/LME/releases/latest | jq -r '.assets[0].browser_download_url' | xargs -I {} sh -c 'curl -L -O {} && unzip -d ~/LME $(basename {})'
   ```

1. Install LME:
   ```bash
   cd ~/LME
   ansible-playbook ansible/upgrade_lme.yml
   ```

The installer will:
- Back up existing container data (when prompted)
- Stop running containers
- Pull new container images with updated versions
- Update configuration files as needed
- Restart services
- Verify all services are running correctly

### Container Versions

LME uses these container versions:
- Elasticsearch/Elastic Agent: 8.18.8
- Kibana: 8.18.8
- Wazuh Manager: 4.9.1
- ElastAlert2: 2.20.0

These versions are defined in:
1. `ansible/site.yml` for Kibana
2. `config/containers.txt` for all containers
3. `lme-environment.env` as STACK_VERSION

## Troubleshooting

If you encounter issues during the upgrade:

1. Check the Ansible logs
2. Verify container status with:
   ```bash
   podman ps -a
   ```
3. Check container logs with:
   ```bash
   podman logs [container_name]
   ```

For persistent issues, you can revert to the previous version by:
1. Restoring the backup data
2. Using the previous container images via:
   ```bash
   cd /opt/lme/ansible
   ansible-playbook rollback_lme.yml
   ```

## Version History

- **2.1.0**: Initial versioned release with container tagging and version tracking 