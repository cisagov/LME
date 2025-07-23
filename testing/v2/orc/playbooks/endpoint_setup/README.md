# Windows Agent Installation Playbooks

This repository contains Ansible playbooks for installing Elastic Agent and Sysmon on Windows machines.

# TODO

We want to automate this as much as possible. To include downloading the agent, dynamically updating files as needed (inventory.ini etc), use api to enroll in fleet and grab enrollment token. Until then this is a manual process.

## Prerequisites

- Ansible installed on the control node
- Windows targets configured for WinRM connectivity (port 5985)
- Inventory file with your Windows hosts

## Required Files

Before running these playbooks, you must:

1. Download the Elastic Agent ZIP file for Windows x86_64 from the Elastic website
2. Create the necessary directory structure:
   ```
   .
   ├── inventory.ini
   ├── install_elastic_agent.yml
   ├── run_sysmon_install_script.yml
   └── files/
       ├── elastic-agent-8.15.5-windows-x86_64.zip
       └── install_sysmon.ps1
   ```

## Configuration

1. Edit `inventory.ini` to include your Windows hosts and credentials:
   ```
   [windows]
   win1 ansible_host=192.168.1.101
   win2 ansible_host=192.168.1.102
   
   [windows:vars]
   ansible_user=Administrator
   ansible_password=YourPassword
   ansible_connection=winrm
   ansible_winrm_server_cert_validation=ignore
   ```

2. In `install_elastic_agent.yml`, update these variables:
   - `fleet_url`: Replace `YOURFLEETIP` with your actual Fleet server IP address
   - `enrollment_token`: Replace with your actual Fleet enrollment token

## Usage

Run the playbooks in the correct order:

```bash
# First install Elastic Agent
ansible-playbook -i inventory.ini install_elastic_agent.yml

# Then install Sysmon
ansible-playbook -i inventory.ini run_sysmon_install_script.yml
```

## Testing

- Test connectivity before running playbooks:
  ```bash
  ansible windows -i inventory.ini -m win_ping
  ```

## Playbook Details

- `install_elastic_agent.yml`: Installs Elastic Agent with Fleet enrollment
- `run_sysmon_install_script.yml`: Installs Sysmon using a custom PowerShell script