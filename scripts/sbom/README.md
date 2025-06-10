# SBOM Generation
This directory is for advanced users that want to generate an SBOM for LME.
There are two scripts: a shell script for generating SBOM files from the installed containers
and the LME repository, and a python script for grabbing installed apt and nix packages
from the installation playbooks.

The shell script uses the tool [syft](https://github.com/anchore/syft) to generate
SBOM files for each of the containers and the LME directory. Syft does not scan 
ansible yaml files -- we've included a python script to handle that.

## Generating SBOM files

### LME Containers
The script `./generate-container-sbom.sh` can be run to generate an SBOM for the
podman containers and the LME directory (besides the install script).
The script will take around 15-20 minutes to run.

**Warning: This script installs the 'syft' tool onto the host machine and generates a podman socket.
Do not proceed unless you have reviewed and understand the script's operation.**

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

All SBOM files will be saved to `./output/`. Two files will be generated for each
container: a SPDX json file and a syft table file. 

Total estimated size of all SBOM files is around 40MB.

### Ansible Playbook SBOM
The script `./generate-ansible-sbom.py` will generate an SBOM for the ansible install playbook set.
It parses the playbooks that install apt and nix packages and creats an SPDX json SBOM file.

This script requires the `pyyaml` python package.

```bash

python3 -m venv venv
source venv/bin/activate
pip install pyyaml

python3 ./generate-ansible-sbom.py
```

The SBOM file will be saved to `output/ansible-spdx.json` in the SPDX json format.
