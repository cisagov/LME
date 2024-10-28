
# Logging Made Easy (LME) Security Model

This document describes LME's security model from the perspective of the LME user. 
It is intended to help users understand the security model and make informed decisions about how to deploy and manage LME given the constraints and assumptions in LME's design.

## Operating System: 
Logging made easy has been tested on ubuntu 22.04, but in theory should be able to support any unix operating system that can install the dependencies listed in the readme.
We assume your operating system is kept up to date, and the linux kernel is up to date and patched.
Failing to patch your operating system could leave your security infrastructure vulnerable.
In addition, if a side channel or denial of service (DoS) attack is ever discovered at the operating system level, LME considers these attacks out of scope for something we can reasonably secure against. 

## Users:
  1. **Root**: Every linux operating system has a root user. As the root user, ensure least privilege access to root following lockdown/harding best practices (e.g. disabling root login, securing administrator access, disabling root over ssh [See More Details](https://wiki.archlinux.org/title/Security#Restricting_root)).  
  2. **Administrators (i.e. those with sudo access)**: LME runs all its architecture through administrator services, so anyone with administrator access will have access to all LME data. Ensure only trusted users are given access to the `sudo` group.  Administrators can start/stop LME services and also manage the service user passwords. Administrators will control the master password to each server user.
  3. **Container User**: These are the users that execute the processes within the context of a LME service container and should not be touched except via `podman exec`. Their passwords are either initialized or locked, and they execute within their own user namespace. For the most part, these are abstracted away from the typical LME administrator. Some more information on [User name Spaces](https://www.man7.org/conf/meetup/understanding-user-namespaces--Google-Munich-Kerrisk-2019-10-25.pdf) [Podman User Namespaces](https://www.redhat.com/sysadmin/rootless-podman-user-namespace-modes)
  4. **Service User**: These are the user/password combinations used to administer, access, and update LME services via their respective APIs. All Service Users passwords are encrypted into individual Ansible Vault files, and encrypted using the master password. The Service User's password will only be decrypted as a Podman secret shared into the container via its environment. The users are: `elastic`, `kibana_system`, and `wazuh-wui`.

## Services Containerized:
All services that make up LME (as documented in our [diagram](https://github.com/cisagov/LME/blob/release-2.0.0/docs/imgs/lme-architecture-v2.jpg)) are configured to execute in Podman containers started via systemd services using Podman's internal quadlet orchestration system.
The quadlets are installed into the system administrator's directory `/etc/containers/systemd/`, and will start up under root's privileges (similar to other systemd root services).  

This ensures least privilege of throughout LME architecture:  
  1. The master password file (used to encrypt service user passwords at rest) is owned by root. 
  2. Eacher Service User password is encrypted with the above password, and only required service user password files are shared to each respective container.
  3. Even on a full container escape (where an adversary can execute code on the host, outside of the container), the rootuid of each service container, is a non-privileged userid on the host, so they cannot gain access to anything (file, network, password, etc...) they would have access to already in the container. 



