# ludus_lme_agents

Installs Elastic Agent and Wazuh Agent on Linux and Windows endpoints for [LME](https://github.com/cisagov/LME). Supports selective installation via `tasks_from: elastic` or `tasks_from: wazuh`.

## Requirements

- A running LME server (deploy with `ludus_lme_server` role first)
- Ansible collections: `ansible.windows`, `community.windows` (for Windows targets)

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_lme_agents_server_ip` | `""` | LME server IP (required) |
| `ludus_lme_agents_elastic_password` | `""` | Elastic password (enables API discovery) |
| `ludus_lme_agents_enrollment_token` | `""` | Fleet enrollment token (auto-fetched if password set) |
| `ludus_lme_agents_elastic_user` | `"elastic"` | Elasticsearch API user |
| `ludus_lme_agents_fleet_port` | `8220` | Fleet server port |
| `ludus_lme_agents_kibana_port` | `5601` | Kibana port |
| `ludus_lme_agents_es_port` | `9200` | Elasticsearch port |
| `ludus_lme_agents_agent_arch` | `"x86_64"` | Agent architecture |
| `ludus_lme_agents_wazuh_manager_ip` | (server_ip) | Wazuh manager IP |
| `ludus_lme_agents_wazuh_retries` | `30` | Wazuh registration retries |
| `ludus_lme_agents_wazuh_delay` | `10` | Seconds between retries |
| `ludus_lme_agents_sysmon_url` | Sysinternals URL | Sysmon download URL |
| `ludus_lme_agents_sysmon_config_url` | SwiftOnSecurity URL | Sysmon config URL |
| `ludus_lme_agents_audit_rules_url` | Neo23x0 URL | Linux audit rules URL |

## What Gets Installed

| Component | Linux | Windows |
|-----------|:-----:|:-------:|
| Elastic Agent | Y | Y |
| auditd + rules | Y | - |
| Sysmon | - | Y |
| Wazuh Agent | Y | Y |

## Selective Installation

```yaml
# Elastic Agent only
- ansible.builtin.include_role:
    name: ludus_lme_agents
    tasks_from: elastic

# Wazuh Agent only
- ansible.builtin.include_role:
    name: ludus_lme_agents
    tasks_from: wazuh
```

## Example Ludus Range Config

```yaml
ludus:
  - vm_name: "{{ range_id }}-win11-workstation"
    hostname: "{{ range_id }}-win11-ws"
    template: win11-22h2-x64-enterprise-template
    vlan: 10
    ip_last_octet: 23
    ram_gb: 8
    cpus: 2
    windows:
      sysprep: false
    roles:
      - name: ludus_lme_agents
        depends_on:
          - vm_name: "{{ range_id }}-lme-server"
            role: ludus_lme_server
    role_vars:
      ludus_lme_agents_server_ip: "10.{{ range_second_octet }}.10.22"
```

## Dependencies

None. Requires `ludus_lme_server` to have been deployed first (use `depends_on` in range config).

## License

GPLv3

## Author

cisagov
