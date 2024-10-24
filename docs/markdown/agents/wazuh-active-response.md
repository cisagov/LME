# Example Setup for Wazuh Active Response

This guide summarizes how to configure Wazuh's active response to defend against SSH brute-force attacks.

## Overview

Wazuh can automatically block IP addresses attempting SSH brute-force attacks using its active response module. This feature executes scripts on monitored endpoints when specific triggers occur.

## Configuration Steps

1. **Verify Default Script**:
   - Check for `firewall-drop` script in `/var/ossec/active-response/bin/` on Linux/Unix systems.

2. **Configure Command in wazuh_manager.conf**: Note this command (firewall-drop) already exists. But you can create custom scripts located in the active response/bin path and add new commands into the .conf file located at wazuh_manger.conf located at /opt/lme/config/wazuh_cluster/wazuh_manager.conf



   ```xml
   <command>
     <name>firewall-drop</name>
     <executable>firewall-drop</executable>
     <timeout_allowed>yes</timeout_allowed>
   </command>
   ```

3. **Set Up Active Response**: Looks for the section that says "active-reponse options here" in the .conf file. Copy and paste the entire configuration below that commented out line. You can continue to add more active reponse configs below that line.
   ```xml
   <active-response>
     <command>firewall-drop</command>
     <location>local</location>
     <rules_id>5763</rules_id>
     <timeout>180</timeout>
   </active-response>
   ```
   - This configures a local response, triggering on rule 5763 (SSH brute-force detection), with a 180-second block.

4. **Restart Wazuh Manager**:
   ```bash
   podman restart lme-wazuh-manager
   ```

## How It Works

- When rule 5763 triggers (detecting SSH brute-force attempts), the `firewall-drop` script executes.
- The script uses iptables to block the attacker's IP address for the specified timeout period.
- Wazuh logs the action in `/var/ossec/logs/active-responses.log`.

## Monitoring

- Wazuh dashboard displays alerts when rule 5763 triggers and when an active response occurs.
- The active response alert is typically associated with rule ID 651. These alerts will be displayed in Kibana in the wazuh alerts dashboard.

## Testing

1. Use a tool like Hydra to simulate a brute-force attack, or you can just attemp to SSH into the machine multiple times until it triggers. You will need 8 failed SSH attemps in order to trigger Brute Force. (This can be adjusted in the ruleset manually)
2. Verify that the attacker's IP is blocked by attempting to ping the target machine.

## Custom Responses

- You can create custom scripts for different actions.
- For custom scripts, ensure you create corresponding rules to analyze the generated logs.

This setup provides an automated defense against SSH brute-force attacks, enhancing the security of your Linux/Unix systems monitored by Wazuh.

See a list of Wazuh Rules that trigger here: [Wazuh Ruleset](https://github.com/wazuh/wazuh/tree/master/ruleset/rules)

Consult Wazuh Documentation for more on active response configuration.