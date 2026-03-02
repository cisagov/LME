# Ansible Installation on Rocky Linux 9 Containers

## Overview

Rocky Linux 9 typically has full EPEL support, so `ansible-core` is often available via `dnf`. The LME install script tries dnf first and falls back to pip if needed.

## If dnf Installation Works

```bash
dnf install -y ansible-core jq
```

## If dnf Installation Fails (Fallback to pip)

Some minimal images or restricted environments may not have ansible-core in EPEL. Use pip:

```bash
dnf install -y python3-pip
pip3 install ansible-core
```

**Critical**: pip installs ansible binaries to `/usr/local/bin/`, but `sudo -i` (used by `extract_secrets.sh` at runtime) does not include that path. Symlink them:

```bash
for f in /usr/local/bin/ansible*; do ln -sf "$f" /usr/bin/; done
```

## Summary

- **Rocky Linux 9 usually supports ansible-core via dnf/EPEL.**
- **The install script falls back to pip if dnf fails.**