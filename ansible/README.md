# LME Ansible Playbooks

This directory contains the Ansible playbooks and roles used to deploy, manage, and maintain the Logging Made Easy (LME) stack.

## Directory Structure

```
ansible/
├── site.yml              # Main installation playbook
├── backup_lme.yml         # Backup operations playbook
├── change_passwords.yml   # Password change playbook
├── convert_to_cluster.yml # Single-node to cluster conversion playbook
├── upgrade_lme.yml        # Upgrade operations playbook  
├── rollback_lme.yml       # Rollback operations playbook
├── rolling_upgrade.yml    # ES cluster rolling upgrade playbook
├── snapshot_elasticsearch.yml # Snapshot repository and snapshot management
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
    ├── load_env.yml       # Environment variable loading
    └── pre_upgrade_checks.yml # Pre-upgrade verification checks
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

- **`change_passwords.yml`**: Changes built-in user passwords across the LME stack
  - Supports `elastic`, `kibana_system`, `wazuh`, and `wazuh_api`
  - Works for both single-node and cluster deployments
  - Updates Elasticsearch via REST API; updates Wazuh via RBAC tool
  - Validates passwords against Have I Been Pwned (skippable in offline mode)

- **`snapshot_elasticsearch.yml`**: Manages Elasticsearch snapshot repositories and creates snapshots
  - Supports `fs` (filesystem) and `s3` repository types
  - Verifies repository accessibility on all cluster nodes
  - Creates timestamped snapshots (can be skipped with `-e create_snapshot=false`)
  - Works with single-node and cluster deployments

- **`rolling_upgrade.yml`**: Performs a rolling upgrade of Elasticsearch across cluster nodes
  - Upgrades one node at a time to maintain cluster availability
  - Runs pre-upgrade checks (health, version, disk, snapshot) by default
  - Creates a pre-upgrade snapshot before upgrading (opt-out with `-e create_pre_upgrade_snapshot=false`)

- **`convert_to_cluster.yml`**: Converts an existing single-node LME installation into a multi-node Elasticsearch cluster
  - Requires a healthy single-node LME on the master and a cluster inventory
  - Creates a backup before conversion
  - Deploys Elasticsearch to new nodes and joins them to the cluster
  - Use `scripts/convert_to_cluster.sh` as a convenience wrapper (generates inventory, then runs the playbook)

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

### Snapshot Operations
Register an Elasticsearch snapshot repository, verify it, and optionally create a snapshot. Supports filesystem (`fs`) and S3 repository types.

```bash
# Single-node: register repo, verify, and create snapshot
ansible-playbook -i ansible/inventory/single.yml ansible/snapshot_elasticsearch.yml

# Register and verify only (no snapshot)
ansible-playbook -i ansible/inventory/single.yml ansible/snapshot_elasticsearch.yml -e create_snapshot=false

# Cluster
ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml

# S3 repository
ansible-playbook -i ansible/inventory/single.yml ansible/snapshot_elasticsearch.yml \
  -e es_snapshot_repo_type=s3 -e es_s3_bucket=my-bucket -e es_s3_region=us-west-2
```

For full details on shared storage requirements and S3 setup, see **[SNAPSHOT_README.md](SNAPSHOT_README.md)**.

### Password Changes
Change built-in user passwords (elastic, kibana_system, wazuh, wazuh_api). Requires a running LME installation and ansible-vault password configured at `/etc/lme/pass.sh`.

```bash
# Single-node (Elasticsearch elastic user)
ansible-playbook ansible/change_passwords.yml \
  -e lme_user=elastic -e lme_password='YourNewSecurePassword123!'

# Cluster (run from master with ansible/inventory/cluster.yml)
ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
  -e lme_user=elastic -e lme_password='YourNewSecurePassword123!'

# Offline environments (skip Have I Been Pwned breach check)
ansible-playbook ansible/change_passwords.yml \
  -e lme_user=elastic -e lme_password='YourNewSecurePassword123!' -e offline_mode=true
```

For clusters, ensure SSH connectivity from master to all nodes before running.

### Single-Node to Cluster Conversion
Convert an existing single-node LME installation into a multi-node Elasticsearch cluster. Prerequisites: healthy single-node LME on master, cluster inventory at `ansible/inventory/cluster.yml`, SSH connectivity from master to all cluster nodes, ports 9200 and 9300 open between nodes.

```bash
# Option 1: Use the wrapper script (generates inventory interactively, then runs playbook)
sudo bash scripts/convert_to_cluster.sh

# Option 2: Run the playbook directly (inventory must already exist)
ansible-playbook -i ansible/inventory/cluster.yml ansible/convert_to_cluster.yml

# Non-interactive / CI (skip backup prompt)
ansible-playbook -i ansible/inventory/cluster.yml ansible/convert_to_cluster.yml -e skip_prompts=true
```

Generate the cluster inventory with `scripts/create_cluster_inventory.sh` if you don't have one. The wrapper script can skip inventory generation with `--skip-inventory` if `ansible/inventory/cluster.yml` already exists.

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