# LME Ansible Playbooks

This directory contains the Ansible playbooks and roles used to deploy, manage, and maintain the Logging Made Easy (LME) stack.

## Directory Structure

```
ansible/
├── site.yml              # Main installation playbook
├── backup_lme.yml         # Backup operations playbook
├── upgrade_lme.yml        # Upgrade operations playbook  
├── rollback_lme.yml       # Rollback operations playbook
├── requirements.yml       # Ansible collection dependencies
├── roles/                 # Ansible roles for different components
│   ├── backup_lme/        # LME backup operations
│   ├── base/              # Common tasks and configurations
│   ├── dashboards/        # Kibana dashboard deployment
│   ├── elasticsearch/     # Elasticsearch configuration
│   ├── fleet/             # Fleet server configuration
│   ├── kibana/            # Kibana configuration
│   ├── nix/               # Nix package manager setup
│   ├── podman/            # Podman container runtime setup
│   └── wazuh/             # Wazuh server configuration
└── tasks/                 # Shared task files
    └── load_env.yml       # Environment variable loading
```

## Main Playbooks

### Installation
- **`site.yml`**: Main installation playbook that orchestrates the complete LME deployment
  - Installs and configures all LME components
  - Sets up container runtime (Podman)
  - Configures security and networking
  - Deploys dashboards and integrations

### Maintenance Operations
- **`backup_lme.yml`**: Creates backups of LME installation and data
  - Backs up configuration files
  - Backs up Podman volumes containing data
  - Creates timestamped backup directories
  - Supports automated and interactive modes

- **`upgrade_lme.yml`**: Upgrades LME to newer versions
  - Checks current version and upgrade requirements
  - Optional backup creation before upgrade
  - Updates container images and configurations
  - Validates successful upgrade

- **`rollback_lme.yml`**: Rolls back LME to a previous backup
  - Lists available backups with version information
  - Optional safety backup before rollback
  - Restores configuration and volume data
  - Validates successful rollback

## Roles

### Core Infrastructure
#### Base Role (`roles/base/`)
- System prerequisites and common configurations
- Password management and encryption setup
- User and directory creation
- Environment variable configuration

#### Nix Role (`roles/nix/`)
- Installs Nix package manager for reproducible builds
- Configures multi-user Nix installation
- Sets up Nix channels and environment

#### Podman Role (`roles/podman/`)
- Installs Podman container runtime via Nix
- Configures container storage and networking
- Sets up Quadlet for systemd integration
- Manages container secrets and policies

### LME Components
#### Elasticsearch Role (`roles/elasticsearch/`)
- Deploys and configures Elasticsearch cluster
- Sets up security certificates and users
- Configures indices and index templates
- Manages cluster settings and policies

#### Kibana Role (`roles/kibana/`)
- Deploys Kibana web interface
- Configures authentication and security
- Sets up space and user management
- Integrates with Elasticsearch cluster

#### Wazuh Role (`roles/wazuh/`)
- Deploys Wazuh security platform
- Configures Wazuh manager and API
- Sets up RBAC and user permissions
- Integrates with Elasticsearch for log storage

#### Fleet Role (`roles/fleet/`)
- Configures Elastic Fleet server
- Sets up agent enrollment and policies
- Manages Fleet server certificates
- Configures output destinations

#### Dashboards Role (`roles/dashboards/`)
- Imports Kibana dashboards and visualizations
- Configures dashboard permissions
- Sets up saved searches and index patterns
- Manages dashboard updates and versioning

#### Backup Role (`roles/backup_lme/`)
- Handles LME backup operations
- Manages volume and configuration backups
- Creates backup manifests and metadata
- Supports incremental and full backups

## Shared Components

### Tasks (`tasks/`)
- **`load_env.yml`**: Loads environment variables from `lme-environment.env`
  - Parses configuration file
  - Sets Ansible facts for use across roles
  - Handles environment variable validation

### Dependencies (`requirements.yml`)
- Defines required Ansible collections:
  - `community.general`: Extended functionality
  - `ansible.posix`: POSIX system management

## Usage

### Initial Installation
```bash
# Install dependencies
ansible-galaxy install -r requirements.yml

# Run main installation
ansible-playbook site.yml
```

### Backup Operations
```bash
# Create a backup (interactive)
ansible-playbook backup_lme.yml

# Create a backup (automated)
ansible-playbook backup_lme.yml -e skip_prompts=true
```

### Upgrade Operations
```bash
# Upgrade LME (with backup prompt)
ansible-playbook upgrade_lme.yml

# Upgrade LME (skip backup - not recommended)
# User will be prompted to choose y/yes or n/no
```

### Rollback Operations
```bash
# Rollback to previous version (with safety backup prompt)
ansible-playbook rollback_lme.yml

# User will be prompted to:
# 1. Select which backup to restore from
# 2. Choose whether to create a safety backup
```

## Configuration

### Environment Variables
Key configuration is stored in `/opt/lme/lme-environment.env`:
- IP addresses and ports
- Stack versions
- Service usernames
- Container image references

### Secrets Management
- Passwords are encrypted using Ansible Vault
- Stored in `/etc/lme/vault/`
- Managed through Podman secrets integration
- Accessed via `../scripts/extract_secrets.sh`

### Container Management
- Container images defined in `../config/containers.txt`
- Quadlet files for systemd integration
- Podman volumes for persistent data
- Network configuration for service communication

## Security Features

- **Encrypted Passwords**: All passwords encrypted with Ansible Vault
- **Secure Secrets**: Integration with Podman secrets driver
- **Certificate Management**: Automatic SSL/TLS certificate generation
- **Access Controls**: Role-based access control (RBAC) configuration
- **Network Security**: Isolated container networks

## Troubleshooting

### Debug Mode
Enable verbose output:
```bash
ansible-playbook site.yml -e debug_mode=true
```

### Common Issues
- **Service Dependencies**: Ensure all services start in correct order
- **Volume Permissions**: Check container user/group mappings
- **Network Connectivity**: Verify container network configuration
- **Certificate Issues**: Check certificate generation and trust

### Log Locations
- Ansible logs: Standard output during playbook execution
- Container logs: `podman logs <container_name>`
- System logs: `journalctl -u lme.service`

## Advanced Usage

### Tags
Run specific components:
```bash
# Install only base components
ansible-playbook site.yml --tags base

# Install only system services
ansible-playbook site.yml --tags system
```

### Custom Variables
Override default values:
```bash
ansible-playbook site.yml -e clone_directory=/custom/path
```

For detailed information about backup, upgrade, and rollback operations, see the respective README files for each operation. 