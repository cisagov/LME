# ludus_caldera_agent

Installs the [MITRE Caldera](https://github.com/mitre/caldera) sandcat agent on Windows endpoints. The agent persists via a Windows Registry Run key and connects to the Caldera server on boot.

## Requirements

- A running Caldera server (deploy with `ludus_caldera_server` role first)
- Windows 10/11 or Windows Server 2019+

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_agent_server_ip` | `""` | Caldera server IP (auto-discovered from facts if empty) |
| `ludus_caldera_agent_server_port` | `8888` | Caldera HTTP port |
| `ludus_caldera_agent_path` | `C:\Users\Public\splunkd.exe` | Agent binary path on target |
| `ludus_caldera_agent_group` | `"red"` | Agent group name |
| `ludus_caldera_agent_script_dir` | `C:\ludus` | Startup script directory |
| `ludus_caldera_agent_reboot` | `true` | Reboot after install to start agent |

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
      - name: ludus_caldera_agent
        depends_on:
          - vm_name: "{{ range_id }}-caldera-server"
            role: ludus_caldera_server
    role_vars:
      ludus_caldera_agent_server_ip: "10.{{ range_second_octet }}.10.21"
```

## Dependencies

None. Requires `ludus_caldera_server` to have been deployed first (use `depends_on` in range config).

## License

GPLv3

## Author

cisagov
