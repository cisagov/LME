# ludus_caldera_server

Deploys [MITRE Caldera](https://github.com/mitre/caldera) adversary emulation platform on a Ludus VM. Installs all prerequisites (Go, Node, Python), clones Caldera, and runs it as a systemd service.

## Requirements

- Ubuntu 22.04+ or Debian 12+
- 4 GB RAM minimum (8 GB recommended)
- Internet access for cloning Caldera and downloading dependencies

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_server_version` | `"5.3.0"` | Caldera git branch/tag |
| `ludus_caldera_server_go_version` | `"1.23.3"` | Go version |
| `ludus_caldera_server_node_version` | `"22"` | Node.js major version |
| `ludus_caldera_server_nvm_version` | `"0.40.1"` | NVM version |
| `ludus_caldera_server_repo_url` | GitHub URL | Caldera git repo |
| `ludus_caldera_server_install_dir` | `/opt/caldera` | Install directory |
| `ludus_caldera_server_port` | `8888` | HTTP port |
| `ludus_caldera_server_sleep_min` | `2` | Agent min sleep (seconds) |
| `ludus_caldera_server_sleep_max` | `5` | Agent max sleep (seconds) |
| `ludus_caldera_server_insecure` | `true` | Run in HTTP (insecure) mode |

## Exposed Facts

After installation, this role sets the following facts on `localhost`:

| Fact | Description |
|------|-------------|
| `caldera_ip` | IP address of the Caldera server |
| `caldera_api_key` | Red team API key |
| `caldera_passwords` | User credentials from default.yml |

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
```

## Dependencies

None.

## License

GPLv3

## Author

cisagov
