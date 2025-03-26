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
│   ├── nix/              # Nix configuration
│   ├── podman/           # Podman configuration
│   ├── wazuh/            # Wazuh server configuration
└── scripts/
    └── extract_secrets.sh # Script to extract sensitive credentials
```

## Key Files

### Main Playbooks

- `site.yml`: The main playbook that orchestrates the entire deployment process. It:
  - Defines the order of role execution
  - Handles pre and post-deployment tasks
  - Manages the overall deployment flow

- `inventory.yml`: Defines the target hosts and their groupings. It includes:
  - Host definitions for the LME server
  - Group definitions for different components
  - Variables specific to each host/group

### Roles

#### Common Role (`roles/base/`)
- Contains shared configurations and tasks used across all roles
- Handles basic system setup and prerequisites
- Manages common dependencies and configurations

#### Dashboards Role (`roles/dashboards/`)
- Deploys Kibana dashboards for both Elastic and Wazuh
- Handles dashboard file management and permissions
- Includes retry logic for dashboard uploads
- Manages dashboard import through Kibana API

#### Elastic Role (`roles/elastic/`)
- Configures Elasticsearch server
- Sets up security settings and users
- Manages Elasticsearch indices and templates
- Handles Elasticsearch service configuration

#### Filebeat Role (`roles/filebeat/`)
- Deploys and configures Filebeat agents
- Sets up log collection from various sources
- Configures output to Logstash
- Manages Filebeat service

#### Kibana Role (`roles/kibana/`)
- Configures Kibana server
- Sets up security and authentication
- Manages Kibana service
- Configures Kibana connection to Elasticsearch

#### Logstash Role (`roles/logstash/`)
- Deploys and configures Logstash
- Sets up pipeline configurations
- Manages log processing rules
- Configures Logstash service

#### Nginx Role (`roles/nginx/`)
- Sets up Nginx as reverse proxy
- Configures SSL/TLS
- Manages access controls
- Handles proxy settings for various services

#### Wazuh Role (`roles/wazuh/`)
- Configures Wazuh server
- Sets up Wazuh manager
- Manages Wazuh service
- Configures Wazuh API

#### Wazuh Agent Role (`roles/wazuh-agent/`)
- Deploys Wazuh agents to target systems
- Configures agent settings
- Manages agent registration
- Handles agent service


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