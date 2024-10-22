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

1. Download the latest `audit.rules` file from the Neo23x0 GitHub repository (or somewhere else).
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

You can now install the auditd elastic integration to collect auditd logs.

## Automated Installation Script

For a more streamlined installation process, you can use the following bash script:

```bash
#!/bin/bash

set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Inform the user that auditd is being installed
echo "Installing and configuring auditd, please wait..."

# Determine the OS ID
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
else
    echo "Cannot determine the operating system."
    exit 1
fi

# Install auditd based on the OS
case "$OS_ID" in
    ubuntu|debian)
        apt update > /dev/null 2>&1
        apt install -y auditd audispd-plugins > /dev/null 2>&1
        ;;
    centos|rhel)
        yum install -y audit > /dev/null 2>&1
        ;;
    fedora)
        dnf install -y audit > /dev/null 2>&1
        ;;
    *)
        echo "Unsupported OS: $OS_ID"
        exit 1
        ;;
esac

# Create the rules directory if it doesn't exist
mkdir -p /etc/audit/rules.d > /dev/null 2>&1

# Download the audit rules
curl -o /etc/audit/rules.d/audit.rules https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules > /dev/null 2>&1

# Load the audit rules, suppressing output and errors
augenrules --load > /dev/null 2>&1

# Restart the auditd service, suppressing output
systemctl restart auditd > /dev/null 2>&1

# Notify the user of successful completion
echo "auditd installed and rules applied successfully."
```

To use this script:

1. Save it to a file, e.g., `install_auditd.sh`
2. Make it executable: `chmod +x install_auditd.sh`
3. Run it with sudo: `sudo ./install_auditd.sh`
