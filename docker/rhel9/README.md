# LME RHEL9 Container

This directory contains the Docker configuration for running LME (Logging Made Easy) on RHEL9/UBI9.

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

### Optional: RHEL Subscription (for package manager installation)
If you have a Red Hat Enterprise Linux subscription and want to use package manager installation instead of pip:

1. **Register the container** with your RHEL subscription:
   ```bash
   docker exec -it lme subscription-manager register --username <your-username> --password <your-password>
   ```

2. **Attach to a subscription**:
   ```bash
   docker exec -it lme subscription-manager attach --auto
   ```

3. **Enable Ansible repositories**:
   ```bash
   docker exec -it lme subscription-manager repos --enable ansible-2.9-for-rhel-9-x86_64-rpms
   ```

4. **Install Ansible via package manager**:
   ```bash
   docker exec -it lme dnf install -y ansible-core
   ```

**Note**: Without a RHEL subscription, the install script will automatically fall back to pip installation.

## Quick Start

1. **Build and start the container**:
   ```bash
   docker compose up -d --build
   ```

2. **Run the LME installation**:
   ```bash
   docker exec -it lme bash -c "cd /root/LME && sudo ./install.sh"
   ```

3. **Access the services**:
   - Kibana: http://localhost:5601
   - Elasticsearch: http://localhost:9200
   - Fleet Server: http://localhost:8220
   - HTTPS: https://localhost:443

## Container Features

### Pre-installed Components
- **Base System**: RHEL9/UBI9 with systemd support
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
- `HOST_UID`: User ID for lme-user (default: 1001)
- `HOST_GID`: Group ID for lme-user (default: 1001)

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

## Support

For issues related to:
- **Ansible installation**: See [README-ANSIBLE.md](README-ANSIBLE.md)
- **Container setup**: Check the troubleshooting section above
- **LME installation**: Refer to the main LME documentation

## License

This container configuration is part of the LME project. See the main LICENSE file for details. 