# Wazuh Configuration Management

## Managing Wazuh Configuration File

The Wazuh manager configuration file in the LME setup is located at:

```
/opt/lme/config/wazuh_cluster/wazuh_manager.conf
```

This file is mounted into the Wazuh manager container running in Podman. Here's how to manage this configuration:

### Editing the Configuration File

1. Open the file with your preferred text editor (you may need sudo privileges):
   ```
   sudo nano /opt/lme/config/wazuh_cluster/wazuh_manager.conf
   ```

2. Make the necessary changes to the configuration file. Some important sections you might want to modify include:
   - `<global>`: Global settings for Wazuh
   - `<ruleset>`: Define rules and decoders
   - `<syscheck>`: File integrity monitoring settings
   - `<rootcheck>`: Rootkit detection settings
   - `<wodle>`: Wazuh modules configuration

3. Save the changes and exit the editor.

### Applying Configuration Changes

After modifying the configuration file, you need to restart the Wazuh manager service for the changes to take effect:

1. Restart the Wazuh manager container:
   ```
   podman restart lme-wazuh-manager
   ```

   or with systemctl

   ```
   sudo systemctl restart lme-wazuh-manager.service
   ```

2. Check the status of the Wazuh manager to ensure it started successfully:
   ```
   podman logs lme-wazuh-manager
   ```

This command will validate your configuration and report any errors.

### Best Practices

1. Always backup the configuration file before making changes:
   ```
   sudo cp /opt/lme/config/wazuh_cluster/wazuh_manager.conf /opt/lme/config/wazuh_cluster/wazuh_manager.conf.bak
   ```

2. Use comments in the configuration file to document your changes.

3. Test configuration changes in a non-production environment before applying them to your production setup.

4. Regularly review and update your Wazuh configuration to ensure it aligns with your current security needs and policies.

Remember to consult the [official Wazuh documentation](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/index.html) for detailed information on all available configuration options.


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
