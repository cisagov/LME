# SBOM Generation

This directory is for advanced users that want to generate an SBOM for LME.
At this point these scripts are experimental

## Generating SBOM files

### LME Containers

The script `./generate-container-sbom.sh` can be run to generate an SBOM for the
podman containers. The script will take a few minutes to run.

** Warning: This will install the tool 'syft' onto the host machine and generate a podman socket. **
** Do NOT proceed if you do not understand the shell script **

`sudo -i` is required to access the podman environment variables. When running this command
you will need to provide the full path to the script.
```bash
sudo -i /home/{USER}/LME/scripts/sbom/generate-container-sbom.sh
```

This will:
1. install `syft` tool on comptuer if it does not exist
2. start a podman socket
3. use `syft` to analyze each container, save the spdx file
4. stop the podman socket 

All SBOM files will be saved to `output/`

### Ansible Playbook SBOM

The script './generate-ansible-sbom.py' will generate an SBOM for the ansible install playbook.
It will scan the playbook '../../ansible/install_lme_local.yml'

This script requires the python package `pyyaml`. It will not be included in the sbom.

```bash

python3 -m venv venv
source venv/bin/activate
pip install pyyaml

python3 ./generate-ansible-sbom.py ../../ansible/install_lme_local.yml
```

The SBOM file will be saved to output/ansible-spdx.json
