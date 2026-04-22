# ludus_lme_server

Deploys the [LME](https://github.com/cisagov/LME) server stack (Elasticsearch, Kibana, Fleet Server, Wazuh Manager) on a Ludus VM by wrapping LME's canonical `install.sh`.

## Requirements

- Ubuntu 22.04+, or Debian 12+
- 8 GB RAM minimum (32 GB recommended for production)
- Internet access (unless `ludus_lme_server_offline: true`)

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_lme_server_ip` | `""` (auto-detect) | IP address the LME stack binds to |
| `ludus_lme_server_version` | `"2.2.0"` | LME release tag to install |
| `ludus_lme_server_offline` | `false` | Enable air-gapped installation |
| `ludus_lme_server_memory_limit` | `2073741824` | Elasticsearch JVM heap in bytes (2 GB) |
| `ludus_lme_server_repo_url` | `https://github.com/cisagov/LME.git` | LME git repository URL |
| `ludus_lme_server_install_dir` | `/opt/lme-install` | Clone and install directory |

## Exposed Facts

After installation, this role sets the following facts on `localhost` for use by downstream roles (e.g., `ludus_lme_agents`):

| Fact | Description |
|------|-------------|
| `lme_ip` | IP address of the LME server |
| `elastic_password` | Generated Elasticsearch `elastic` user password |

## Example Ludus Range Config

```yaml
ludus:
  - vm_name: "{{ range_id }}-lme-server"
    hostname: "{{ range_id }}-lme"
    template: ubuntu-24.04-x64-server-template
    vlan: 10
    ip_last_octet: 22
    ram_gb: 32
    cpus: 4
    linux: true
    roles:
      - ludus_lme_server
    role_vars:
      ludus_lme_server_version: "2.2.0"
```

## Dependencies

None.

## License

GPLv3

## Author

cisagov
