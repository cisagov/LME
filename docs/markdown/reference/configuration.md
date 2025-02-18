# General notes on custom configuration for LME
The configuration files are located in /config/. These steps will guide you through setting up LME.

## certificates and user passwords:
  - instances.yml defines the certificates to be created.
  - Shell scripts will initialize accounts and generate certificates. They run from the quadlet definitions lme-setup-accts and lme-setup-certs.
   
## Podman Quadlet Configuration
- Quadlet configuration for containers is located in /quadlet/. These map to the root systemd unit files but execute as non-privileged users.
