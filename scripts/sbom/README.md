# SBOM Generation

This directory is for advanced users that want to generate an SBOM for LME.
At this point these scripts are experimental.

## Generating SBOM files

### LME Containers

Running the `./generate-container-sbom.sh` script will generate an SBOM for the
podman containers. The script will take several minutes to complete.

**Warning: This script installs the 'syft' tool onto the host machine and generates a podman socket. Do not proceed unless you have reviewed and understand the script's operation.**

`sudo -i` is required to access the podman environment variables. When running this command,
you will need to provide the full path to the script.
```bash
sudo -i /absolute/path/to/LME/scripts/sbom/generate-container-sbom.sh
```

This will:
1. Install the `syft` tool onto the comptuer if it does not already exist
2. Start a podman socket
3. Use `syft` to analyze each container and save the spdx file
4. Stop the podman socket
5. Use `syft` to scan the LME directory

All SBOM files will be saved to `output/`.

### Ansible Playbook SBOM

The './generate-ansible-sbom.py' script will generate an SBOM for the Ansible install playbook set.
It scans the playbooks that install packages and produces a minimal SBOM for those packages.

This script requires the `pyyaml` python package.

```bash

python3 -m venv venv
source venv/bin/activate
pip install pyyaml

python3 ./generate-ansible-sbom.py
```

The SBOM file will be saved to `output/ansible-spdx.json`.
