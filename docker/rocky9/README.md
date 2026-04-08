# LME Rocky Linux 9 Container

This directory contains the Docker configuration for running LME (Logging Made Easy) on Rocky Linux 9.

## Prerequisites

### System Requirements
- **Docker**: Docker Engine 20.10+ or Docker Desktop
- **Docker Compose**: Version 2.0+
- **Host System**: Linux, macOS, or Windows with Docker support
- **Memory**: Minimum 4GB RAM (8GB+ recommended)
- **Storage**: At least 10GB free space
- **Network**: Internet access for package downloads

### Host System Prerequisites
- **cgroup v2 support**: Required for systemd in containers
- **SYS_ADMIN capability**: Required for privileged container operations
- **Port availability**: Ensure ports 5601, 443, 8220, and 9200 are not in use

### Optional: Rocky Linux Package Manager
Rocky Linux 9 has full EPEL support, so ansible-core and other packages are typically available via dnf without requiring a subscription. The install script will use dnf when available; if ansible-core is not found, it falls back to pip installation.

## Quick Start

### Prerequisites Setup
1. **Set the HOST_IP environment variable**:
   ```bash
   # Copy and edit the environment file
   cp environment_example.sh environment.sh
   # Edit environment.sh to set your HOST_IP
   nano environment.sh
   ```

### Option 1: Manual Installation (Current Default)
1. **Build and start the container**:
   ```bash
   docker compose up -d --build
   ```

2. **Run the LME installation**:
   ```bash
   docker exec -it lme bash -c "cd /root/LME && sudo ./install.sh -d"
   ```

### Option 2: Monitor Setup Progress
If you want to monitor the installation process:
1. **Run the setup checker** (in a separate terminal):
   ```bash
   # For Linux/macOS
   ./check-lme-setup.sh
   
   # For Windows PowerShell
   .\check-lme-setup.ps1
   ```

### Access the Services
Once installation is complete:
- Kibana: http://localhost:5601
- Elasticsearch: http://localhost:9200
- Fleet Server: http://localhost:8220
- HTTPS: https://localhost:443

## Container Features

### Pre-installed Components
- **Base System**: Rocky Linux 9 with systemd support
- **User Management**: `lme-user` with sudo privileges
- **Package Management**: EPEL repository enabled
- **System Services**: systemd with proper configuration
- **Network Tools**: openssh-clients for remote access

### Security Features
- **Sudo Configuration**: Passwordless sudo for lme-user
- **PAM Configuration**: Custom sudo PAM setup for container environment
- **Privileged Mode**: Required for systemd and cgroup access
- **Security Options**: seccomp unconfined for compatibility

### Volume Mounts
- **LME Source**: `/root/LME` - Mounts the LME source code
- **cgroup**: `/sys/fs/cgroup/systemd` - Required for systemd
- **Temporary Filesystems**: `/tmp`, `/run`, `/run/lock`

## Environment Variables

### Required
- `HOST_IP`: IP address for the container (set in environment.sh)

### Optional
- `HOST_UID`: User ID for lme-user (default: 1000)
- `HOST_GID`: Group ID for lme-user (default: 1000)

### Container Environment Variables (Auto-configured)
The following environment variables are automatically set by docker-compose:
- `PODMAN_IGNORE_CGROUPSV1_WARNING`: Suppresses podman cgroup warnings
- `LANG`, `LANGUAGE`, `LC_ALL`: Locale settings (en_US.UTF-8)
- `container`: Set to "docker" for container detection

## Troubleshooting

### Common Issues

#### Ansible Installation Problems
- **Problem**: EPEL Ansible package has missing dependencies
- **Solution**: The install script automatically falls back to pip installation
- **Details**: See [README-ANSIBLE.md](README-ANSIBLE.md) for more information

#### Systemd Issues
- **Problem**: Container fails to start with systemd
- **Solution**: Ensure cgroup v2 is enabled on the host
- **Check**: `docker exec -it lme systemctl status`

#### Port Conflicts
- **Problem**: Port already in use error
- **Solution**: Change ports in docker-compose.yml or stop conflicting services
- **Alternative**: Use different port mappings

#### Permission Issues
- **Problem**: Permission denied errors
- **Solution**: Ensure the container is running with proper privileges
- **Check**: `docker inspect lme | grep -i privileged`

#### Volume Mount Issues
- **Problem**: "No such file or directory" when accessing /root/LME
- **Solution**: Ensure you're running docker-compose from the correct directory
- **Details**: The volume mount `../../../LME:/root/LME` expects the LME directory to be 3 levels up from your current location
- **Fix**: Run docker-compose from the correct path or adjust the volume mount in docker-compose.yml

### Debugging Commands

```bash
# Check container status
docker ps

# View container logs
docker logs lme

# Access container shell
docker exec -it lme bash

# Check systemd status
docker exec -it lme systemctl status

# Verify Ansible installation
docker exec -it lme ansible --version

# Check available repositories
docker exec -it lme dnf repolist

# Monitor setup progress (if using automated setup)
./check-lme-setup.sh  # Linux/macOS
.\check-lme-setup.ps1  # Windows PowerShell
```

### Setup Monitoring
The directory includes setup monitoring scripts that can track installation progress:
- `check-lme-setup.sh`: Linux/macOS script to monitor setup
- `check-lme-setup.ps1`: Windows PowerShell script to monitor setup

These scripts:
- Monitor for 30 minutes by default
- Check for successful completion messages
- Report Ansible playbook failures
- Track progress through multiple playbook executions
- Exit with appropriate status codes for automation

**Note**: These scripts expect an `lme-setup` systemd service to be running. Currently, the automated setup service is disabled in the Rocky Linux 9 container configuration, so these scripts are primarily useful for development or if you enable the automated setup service.

## Cluster Installation

LME supports multi-node Elasticsearch clusters. A 3-node cluster can be deployed using the provided Docker Compose and install script in this directory.

### Quick Start (Docker Cluster)

```bash
cd docker/rocky9
docker compose -f docker-compose-cluster.yml up -d --build
./install_cluster.sh
```

The script supports flags for incremental work:
- `--skip-master` - skip the master `site.yml` install (useful when re-running only the cluster phase)
- `--skip-cluster` - skip the `elasticsearch.yml` cluster phase
- `-d` / `--debug` - verbose Ansible output

### Rocky Linux 9 Cluster Requirements

Deploying a cluster on Rocky Linux 9 may require some workarounds that are **not needed on Ubuntu**. If you are building your own cluster installer or following the manual steps in [CLUSTER_INSTALL.md](../../testing/v2/development/CLUSTER_INSTALL.md), be aware of these items:

#### 1. SSH - PAM Blocks All Users by Default on Some Containers

The cluster uses `lme-user` (with passwordless sudo) for SSH between nodes, the same as the Ubuntu cluster install. However, some container base images have PAM `sshd` configuration that blocks SSH for users in containers without SELinux. The fix is to replace the `account` lines in `/etc/pam.d/sshd` on each cluster child node:

```bash
# Remove the default account lines and add pam_permit.so
sed -i '/^account/d' /etc/pam.d/sshd
sed -i '/^password/i account    required     pam_permit.so' /etc/pam.d/sshd
systemctl restart sshd
```

The `install_cluster.sh` script automates this. On Ubuntu, `lme-user` SSH works out of the box with no PAM changes.

#### 2. Ansible Installation

Rocky Linux 9 typically has EPEL support and ansible-core may be available via dnf. The install script tries dnf first and falls back to pip if needed. If using pip, ansible binaries must be symlinked:

```bash
for f in /usr/local/bin/ansible*; do ln -sf "$f" /usr/bin/; done
```

#### 3. Ansible on Cluster Child Nodes

Child nodes (es2, es3, ...) never run `install.sh`, so they do not get Ansible installed. However, the podman shell secret driver uses `ansible-vault view` at **container runtime** to decrypt secrets. Without `ansible-vault`, the `lme-setup-certs` service fails and Elasticsearch cannot start.

The `elasticsearch.yml` playbook includes `pre_tasks` that install `ansible-core` on cluster nodes automatically. If you are running the playbook manually, ensure `ansible-vault` is available on every cluster node before starting services.

#### 4. Ansible Galaxy Collections

The `community.general` and `ansible.posix` collections are required (they provide modules like `timezone`, `sysctl`, etc.). Install them on the master node:

```bash
cd ~/LME/ansible
ansible-galaxy collection install -r requirements.yml
```

Galaxy downloads can fail transiently. If the first attempt fails, retry.

### Cluster Architecture

| Node | Container Name | Role | Exposed Ports |
|------|---------------|------|---------------|
| node1 (master) | lme_rocky9_cluster_node1 | Full LME stack | 5601, 443, 8220, 9200, 9300, 1514-1515, 55000, 514/udp, 1516 |
| node2 | lme_rocky9_cluster_node2 | Elasticsearch only | 9201, 9301 |
| node3 | lme_rocky9_cluster_node3 | Elasticsearch only | 9202, 9302 |

### Verifying the Cluster

```bash
# Extract credentials and check health
docker exec lme_rocky9_cluster_node1 bash -c \
  "source /nix/var/nix/profiles/default/etc/profile.d/nix.sh; \
   source /opt/lme/scripts/extract_secrets.sh -q && \
   curl -sk -u elastic:\$elastic https://localhost:9200/_cluster/health?pretty"

# List nodes
docker exec lme_rocky9_cluster_node1 bash -c \
  "source /nix/var/nix/profiles/default/etc/profile.d/nix.sh; \
   source /opt/lme/scripts/extract_secrets.sh -q && \
   curl -sk -u elastic:\$elastic https://localhost:9200/_cat/nodes?v"
```

A healthy cluster shows `"status": "green"`, `"number_of_nodes": 3`, and `"unassigned_shards": 0`.

### Cleanup

```bash
docker compose -f docker-compose-cluster.yml down -v
```

## Development

### Building from Source
```bash
# Build the container
docker compose build

# Build with specific arguments
docker compose build --build-arg USER_ID=1000 --build-arg GROUP_ID=1000
```

### Customizing the Container
- Modify `Dockerfile` to add additional packages
- Update `docker-compose.yml` for different port mappings
- Edit `environment.sh` to set custom environment variables

### Differences from Other Docker Setups
The Rocky Linux 9 container setup differs from other LME Docker configurations (22.04, 24.04, d12.10):
- **Manual Installation**: Currently requires manual execution of install.sh
- **No Automated Service**: The lme-setup.service is commented out in the Dockerfile
- **Rocky Linux 9 Base**: Uses Rocky Linux 9 instead of Ubuntu/Debian
- **EPEL Dependencies**: Relies on EPEL repository for additional packages
- **Ansible Installation**: Uses dnf when available; falls back to pip if ansible-core is not in EPEL

## Support

For issues related to:
- **Ansible installation**: See [README-ANSIBLE.md](README-ANSIBLE.md)
- **CA certificate compatibility**: See [README-CA-CERTIFICATES.md](README-CA-CERTIFICATES.md)
- **Container setup**: Check the troubleshooting section above
- **LME installation**: Refer to the main LME documentation

## License

This container configuration is part of the LME project. See the main LICENSE file for details. 