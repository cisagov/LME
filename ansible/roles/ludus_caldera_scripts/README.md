# ludus_caldera_scripts

Deploys MITRE Caldera automation scripts and operation configuration files for programmatic adversary emulation.

## Requirements

- A running Caldera server (deploy with `ludus_caldera_server` role first)
- Python 3 with `requests` library on the target host

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_scripts_server_ip` | `""` | Caldera server IP |
| `ludus_caldera_scripts_install_dir` | `/opt/caldera` | Caldera install dir (for API key extraction) |
| `ludus_caldera_scripts_deploy_dir` | `/opt/caldera-scripts` | Where scripts are deployed |
| `ludus_caldera_scripts_api_key` | `""` | API key (auto-extracted if empty) |

## Deployed Scripts

| Script | Description |
|--------|-------------|
| `run_config.py` | Flexible operation orchestrator — load JSON config, create adversary, run operation |
| `operation.py` | Quick-start script for running a discovery operation |
| `get_abilities.py` | Lists Caldera abilities matching discovery keywords |

## Example Ludus Range Config

```yaml
ludus:
  - vm_name: "{{ range_id }}-caldera-server"
    hostname: "{{ range_id }}-caldera"
    template: ubuntu-24.04-x64-server-template
    vlan: 10
    ip_last_octet: 21
    ram_gb: 8
    cpus: 2
    linux: true
    roles:
      - ludus_caldera_server
      - name: ludus_caldera_scripts
        depends_on:
          - vm_name: "{{ range_id }}-caldera-server"
            role: ludus_caldera_server
```

## Dependencies

None. Requires `ludus_caldera_server` to have been deployed first.

## License

GPLv3

## Author

cisagov
