# Ansible Role: ([Ludus](https://ludus.cloud)) Attack Range Caldera

An Ansible Role that installs Caldera on Ubuntu 22.04.

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):
```
ludus_ar_caldera_go_version: "1.23.3"
ludus_ar_caldera_nvm_version: "0.40.1"
ludus_ar_caldera_node_version: "22"
ludus_ar_caldera_upx_version: "4.2.4"
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: attack_range_caldera
  roles:
    - P4T12ICK.ludus_ar_caldera
```

## Example Ludus Range Config

```yaml
ludus:
  - vm_name: "{{ range_id }}-ar-splunk"
    hostname: "{{ range_id }}-ar-splunk"
    template: ubuntu-22.04-x64-server-template
    vlan: 20
    ip_last_octet: 1
    ram_gb: 16
    cpus: 8
    linux: true
    roles:
      - P4T12ICK.ludus_ar_splunk
      - P4T12ICK.ludus_ar_caldera
```

## License
Apache License 2.0

## Author Information
This role was created by [P4T12ICK](https://github.com/P4T12ICK), for [Ludus](https://ludus.cloud/).
