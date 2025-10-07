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
   # or
   docker exec -it lme subscription-manager register --activationkey=YOUR_ACTIVATION_KEY  --org=YOUR_ORG_ID
   ```

2. **Attach to a subscription (if needed)**:
   ```bash
   docker exec -it lme subscription-manager attach --auto
   ```

3. **Enable Ansible repositories (should be installed by install.sh)**:
   ```bash
   dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
   ```


**Note**: Without a RHEL subscription, the install script will automatically fall back to pip installation.

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

**Note**: These scripts expect an `lme-setup` systemd service to be running. Currently, the automated setup service is disabled in the RHEL9 container configuration, so these scripts are primarily useful for development or if you enable the automated setup service.

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
The RHEL9 container setup differs from other LME Docker configurations (22.04, 24.04, d12.10):
- **Manual Installation**: Currently requires manual execution of install.sh
- **No Automated Service**: The lme-setup.service is commented out in the Dockerfile
- **UBI9 Base**: Uses Red Hat Universal Base Image instead of Ubuntu/Debian
- **EPEL Dependencies**: Relies on EPEL repository for additional packages
- **Ansible Installation**: Automatically falls back to pip installation due to missing ansible-core in EPEL

## Support

For issues related to:
- **Ansible installation**: See [README-ANSIBLE.md](README-ANSIBLE.md)
- **CA certificate compatibility**: See [README-CA-CERTIFICATES.md](README-CA-CERTIFICATES.md)
- **Container setup**: Check the troubleshooting section above
- **LME installation**: Refer to the main LME documentation

## License

This container configuration is part of the LME project. See the main LICENSE file for details. 