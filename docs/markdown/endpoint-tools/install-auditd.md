# Installing and Configuring Auditd on Linux Systems

This guide will walk you through the process of installing auditd on Linux systems and configuring it with the rules provided by Neo23x0.

## Prerequisites

- Root or sudo access to the Linux system
- Internet connection to download necessary files

## Step 1: Install Auditd

The installation process may vary depending on your Linux distribution. Here are instructions for some common distributions:

### For Ubuntu/Debian:

```bash
sudo apt update
sudo apt install auditd audispd-plugins
```

### For CentOS/RHEL:

```bash
sudo yum install audit audit-libs
```

### For Fedora:

```bash
sudo dnf install audit
```

## Step 2: Download Neo23x0 Audit Rules (These are used as an example you can write your own rules)

1. Open a terminal window.
2. Download the audit rules file:
   ```bash
   sudo curl -o /etc/audit/rules.d/audit.rules https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules
   ```

## Step 3: Configure Auditd

1. Open the main auditd configuration file:
   ```bash
   sudo nano /etc/audit/auditd.conf
   ```

2. Review and adjust the settings as needed.

3. Save and close the file (in nano, press Ctrl+X, then Y, then Enter).

## Step 4: Load the New Rules

1. Load the new audit rules:
   ```bash
   sudo auditctl -R /etc/audit/rules.d/audit.rules
   ```

2. Restart the auditd service:
   ```bash
   sudo service auditd restart
   ```

## Step 5: Verify Installation and Rules

1. Check if auditd is running:
   ```bash
   sudo systemctl status auditd
   ```

2. Verify that the rules have been loaded:
   ```bash
   sudo auditctl -l
   ```

## Step 6: Test Audit Logging

1. Perform some actions that should trigger audit logs (e.g., accessing sensitive files, running specific commands).

2. Check the audit log for new entries:
   ```bash
   sudo ausearch -ts recent
   ```

## Updating Audit Rules

To update the audit rules in the future:

1. Download the latest `audit.rules` file from the Neo23x0 GitHub repository.
2. Replace the existing file:
   ```bash
   sudo curl -o /etc/audit/rules.d/audit.rules https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules
   ```
3. Reload the rules and restart auditd:
   ```bash
   sudo auditctl -R /etc/audit/rules.d/audit.rules
   sudo service auditd restart
   ```

Adjust rules as needed to meet compliance requirements.