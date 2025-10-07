# Ansible Installation on RHEL9/UBI9 Containers

## Problem

The EPEL `ansible` package for RHEL9/UBI9 requires `python3.9dist(ansible-core) >= 2.14.7`, but the `ansible-core` RPM is **not available** in any public repository for UBI9 or non-subscribed RHEL9. This results in a broken dependency and prevents installation via `dnf`:

```
dnf install ansible
# Error: nothing provides python3.9dist(ansible-core) >= 2.14.7 needed by ansible-1:7.7.0-1.el9.noarch from epel
```

## Why does this happen?
- Red Hat only provides the `ansible-core` RPM in the main RHEL subscription repositories, **not** in UBI or EPEL.
- UBI images are designed to be redistributable and do not include all RHEL content.
- EPEL expects the RHEL-provided `ansible-core` RPM, but it is not present in UBI or EPEL.

## Solutions

### 1. Use pip (Recommended for UBI9/Non-subscribed RHEL9)
Install Ansible using pip:

```
dnf install -y python3-pip
pip3 install ansible
```

This is the only way to get a working Ansible install on UBI9/RHEL9 containers without a RHEL subscription. This is also the method recommended by the [official Ansible documentation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#pip-install).

### 2. If you have a RHEL subscription
Register the container and enable the official RHEL repositories:

```
subscription-manager register
subscription-manager attach --auto
subscription-manager repos --enable ansible-2.9-for-rhel-9-x86_64-rpms
```

Then you can install Ansible via dnf:

```
dnf install ansible-core
```

### 3. Use a different base image
If you require a pure package-manager install, consider using Rocky Linux, CentOS Stream, or Fedora as your base image, where all dependencies are available via the package manager.

## Summary
- **UBI9 and non-subscribed RHEL9 cannot install Ansible via dnf due to missing dependencies.**
- **Use pip to install Ansible, or use a different base image if you require dnf installation.**