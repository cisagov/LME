# LME Ansible Playbooks

This directory contains the Ansible playbooks and roles used to deploy and configure the Logging Made Easy (LME) stack.

## Directory Structure

```
ansible/
├── site.yml              # Main playbook that orchestrates the deployment
├── roles/
│   ├── base/             # Common tasks and configurations
│   ├── dashboards/       # Kibana dashboard deployment
│   ├── elasticsearch/    # Elasticsearch configuration
│   ├── fleet/            # Fleet configuration
│   ├── nix/              # Nix package manager setup
│   ├── podman/           # Podman container runtime setup
│   └── wazuh/            # Wazuh server configuration
└── scripts/
    └── extract_secrets.sh # Script to extract sensitive credentials
```

## Key Files

### Main Playbooks

- `site.yml`: The main playbook that orchestrates the entire deployment process. It:
  - Defines the order of role execution
  - Handles pre and post-deployment tasks
  - Manages the overall deployment flow


### Roles

#### Base Role (`roles/base/`)
- Contains shared configurations and tasks used across all roles
- Handles basic system setup and prerequisites
- Manages common dependencies and configurations

#### Dashboards Role (`roles/dashboards/`)
- Deploys Kibana dashboards for both Elastic and Wazuh
- Handles dashboard file management and permissions
- Includes retry logic for dashboard uploads
- Manages dashboard import through Kibana API

#### Elasticsearch Role (`roles/elasticsearch/`)
- Configures Elasticsearch server
- Sets up security settings and users
- Manages Elasticsearch indices and templates
- Handles Elasticsearch service configuration

#### Fleet Role (`roles/fleet/`)
- Configures Fleet server
- Sets up Fleet agent management
- Manages Fleet policies and configurations
- Handles Fleet service setup

#### Nix Role (`roles/nix/`)
- Installs and configures Nix package manager
- Sets up multi-user installation
- Manages Nix channels and packages
- Configures Nix environment variables

#### Podman Role (`roles/podman/`)
- Installs and configures Podman container runtime
- Sets up container storage configuration
- Manages Podman service
- Configures container networking

#### Wazuh Role (`roles/wazuh/`)
- Configures Wazuh server
- Sets up Wazuh manager
- Manages Wazuh service
- Configures Wazuh API

### Scripts

- `scripts/extract_secrets.sh`: Utility script that:
  - Extracts sensitive credentials from the environment
  - Provides secure access to required secrets
  - Used by various roles for authentication

## Usage

1. Ensure you have Ansible installed and configured
1. Run the main playbook:
   ```bash
   ansible-playbook -i inventory.yml site.yml
   ```

## Variables

Key variables are defined in:
- Role-specific `defaults/main.yml` files for default values
- `group_vars/` for group-specific configurations

## Security

- Sensitive credentials are managed through environment variables
- SSL/TLS is configured for secure communications
- Access controls are implemented at various levels
- Secrets are extracted securely using the provided script

## Troubleshooting

- Enable debug mode by setting `debug_mode: true` in inventory
- Check role-specific logs in `/var/log/`
- Review Ansible output with increased verbosity:
  ```bash
  ansible-playbook site.yml -vvv
  ``` 