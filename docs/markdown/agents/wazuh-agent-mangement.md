# LME Wazuh Agent Enrollment Guide

- See Official Wazuh Doumentation [Wazuh agent install documentation](https://documentation.wazuh.com/4.7/installation-guide/wazuh-agent/index.html).

This guide will walk you through the process of enrolling a Wazuh agent in the LME (Logging Made Easy) system.

## Important Note

Before proceeding, ensure that the Wazuh agent version you're installing is not newer than the version of the Wazuh manager you're running. Using an agent version that is more recent than the manager version can lead to compatibility issues.

## Variables

Throughout this guide, we'll use the following variables. Replace these with your specific values:

- `{WAZUH_AGENT_VERSION}`: The version of the Wazuh agent you're installing (e.g., 4.9.0-1)
- `{WAZUH_MANAGER_IP}`: The IP address of your Wazuh manager (e.g., 10.0.0.2)

## Steps to Enroll a Wazuh Agent (Windows)

1. **Download the Wazuh Agent**
   - Download the Wazuh agent MSI installer from the following URL:
     ```
     https://packages.wazuh.com/4.x/windows/wazuh-agent-{WAZUH_AGENT_VERSION}.msi
     ```
   - Replace `{WAZUH_AGENT_VERSION}` with the appropriate version number.

2. **Install the Wazuh Agent**
   - Open a command prompt with administrator privileges.
   - Navigate to the directory containing the downloaded MSI file.
   - Run the following command to install the agent:
     ```
     wazuh-agent-{WAZUH_AGENT_VERSION}.msi /q WAZUH_MANAGER="{WAZUH_MANAGER_IP}"
     ```
   - Replace `{WAZUH_AGENT_VERSION}` with the version you downloaded.
   - Replace `{WAZUH_MANAGER_IP}` with the IP address of your Wazuh manager.

3. **Verify Installation**
   - After installation, the Wazuh agent service should start automatically.
   - You can verify the service status in the Windows Services manager.


## Steps to Enroll a Wazuh Agent (Debian-based Systems)

1. **Add Wazuh GPG key**
   ```bash
   curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
   ```

2. **Add Wazuh repository**
   ```bash
   echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
   ```

3. **Update package information**
   ```bash
   apt-get update
   ```

4. **Install Wazuh agent**
   ```bash
   WAZUH_MANAGER="{WAZUH_MANAGER_IP}" apt-get install wazuh-agent={WAZUH_AGENT_VERSION}
   ```

## Verifying Installation

After installation, you can check the status of the Wazuh agent:

```bash
systemctl status wazuh-agent
```

## Troubleshooting

- If the agent fails to connect, check your firewall settings to ensure the necessary ports are open. [Wazuh Ports Documentation](https://documentation.wazuh.com/current/getting-started/architecture.html)
- Verify that the Wazuh manager IP address is correct and reachable from the agent. This is the IP address of your LME server running the containers.

By following these steps, you should be able to successfully enroll Wazuh agents into your LME system. Remember to keep your agents updated, but always ensure compatibility with your Wazuh manager version.


# Verifying Wazuh Agent Status

This guide provides steps to check the status of Wazuh agents in the LME setup. These commands can be run from the host system without needing to execute into the container.

## Listing All Agents and Their Status

To get an overview of all registered agents and their current status:

```bash
podman exec lme-wazuh-manager /var/ossec/bin/agent_control -l
```

This command will display a list of all agents, including their ID, name, IP address, and current status (active, disconnected, never connected, etc.).

## Checking Status of a Specific Agent

To check the detailed status of a specific agent:

```bash
podman exec lme-wazuh-manager /var/ossec/bin/agent_control -i [agent_id]
```

Replace `[agent_id]` with the ID of the agent you want to check. This will provide more detailed information about the agent, including its last keep alive time, version, and operating system.


This command gives you a quick overview of how many agents are active, disconnected, or never connected.

See official Wazuh documentation for more steps on [agent_control](https://documentation.wazuh.com/current/user-manual/reference/tools/agent-control.html)
