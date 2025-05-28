import os
import re
import yaml
import uuid
import json
import hashlib
import argparse
import datetime
import subprocess

from pathlib import Path

class AnsibleParser():
    def __init__(self, path: str):
        self.file_path = path
        self.apt_packages = set()
        self.nix_packages = set()
        self.package_details = dict()
    
    def parse_ansible_playbook(self):
        with open(self.file_path, 'r') as fp:
            playbook = yaml.safe_load(fp)

        for play in playbook:
            for task in play.get('tasks', []):
                self.parse_task(task)
        self.get_package_versions()

    def parse_task(self, task: dict):
        if 'apt' in task:
            self.parse_apt_task(task['apt'])

        if 'nix' in task or any('nix' in str(v).lower() for v in task.values() if isinstance(v, str)):
            self.parse_nix_task(task)

    def parse_apt_task(self, apt_config):
        if isinstance(apt_config, str):
            self.apt_packages.add(apt_config)
        elif isinstance(apt_config, dict):
            name = apt_config.get('name')
            pkg = apt_config.get('pkg')

            packages = name or pkg
            if packages:
                if isinstance(packages, str):
                    self.apt_packages.add(packages)
                elif isinstance(packages, list):
                    self.apt_packages.update(packages)

    def parse_nix_task(self, task):
        for _, value in task.items():
            if isinstance(value, str) and 'nix' in value.lower():
                nix_patterns = [
                    r'nixpkgs\.([a-zA-Z0-9_-]+)',
                    r'nix-env\s+-i\s+([^\s]+)',
                ]
                for pattern in nix_patterns:
                    matches = re.findall(pattern, value)
                    self.nix_packages.update(matches)

    def get_package_versions(self):
        for package in self.apt_packages:
            version = 'unknown'
            try:
                result = subprocess.run(['apt-cache', 'show', package], capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    version_match = re.search(r'Version:\s*([^\n]+)', result.stdout)
                    if version_match:
                        version = version_match.group(1).strip()
            except(subprocess.TimeoutExpired, subprocess.SubprocessError):
                version = 'unknown'

            self.package_details[f"apt:{package}"] = {
                'version': version,
                'type': 'apt',
                'name': package}

        for package in self.nix_packages:
            #TODO: add way to get nix package versions
            self.package_details[f"nix:{package}"] = {
                'version': 'unknown',
                'type': 'nix',
                'name': package
            }

    def generate_spdx(self):
        sbom = {
            "spdxVersion": "SPDX-2.3",
            "dataLicense": "CC0-1.0",
            "SPDXID": "SPDXRef-DOCUMENT",
            "name": "Ansible Install Playbook SBOM",
            #TODO: change document namespace? 
            "documentNamespace": f"https://spdx.org/spdxdocs/spdx-tools-v1.2-{uuid.uuid4()}",
            "creationInfo": {
                "created": datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ"),
                "creators": ["Tool: ansible-sbom-generator"]
            },
            "files": [],
            "packages": [],
            "relationships": [],
        }

        #add root package
        root_package_id = "SPDXRef-Package-Document"
        sbom["packages"].append({
            "SPDXID": root_package_id,
            "name": "Ansible-Deployment-Root",
            "downloadLocation": "NOASSERTION",
            "filesAnalyzed": False,
        })
        sbom["relationships"].append({
            "spdxElementId": "SPDXRef-DOCUMENT",
            "relatedSpdxElement": root_package_id,
            "relationshipType": "DESCRIBES",
        })

        #add file
        with open(self.file_path, 'rb') as fp:
            filedata = fp.read()
        sbom['files'].append({
            "SPDXID": "SPDXRef-File-AnsiblePlaybook",
            "fileName": self.file_path,
            "checksums": [
                {"algorithm": "SHA256", "checksumValue": hashlib.sha256(filedata).hexdigest()},
                {"algorithm": "SHA1", "checksumValue": hashlib.sha1(filedata).hexdigest()},
            ],
            "fileTypes": ["SOURCE"],
            "copyrightText": "NOASSERTION"
        })
        sbom['relationships'].append({
            "spdxElementId": root_package_id,
            "relatedSpdxElement": "SPDXRef-File-AnsiblePlaybook",
            "relationshipType": "DESCRIBES"
        })

        # add pacakges
        for _, packagedata in self.package_details.items():
            name = packagedata['name']
            spdx_id = f"SPDXRef-Package-{name.replace('-','').replace('_','')}"
            referenceLocator = ""
            if packagedata['type'] == 'apt':
                referenceLocator = "pkg:deb/debian"
            elif packagedata['type'] == 'nix':
                referenceLocator = "pkg:nix"

            package_spdx = {
                "SPDXID": spdx_id,
                "name": name,
                "downloadLocation":"NOASSERTION",
                "filesAnalyzed": False,
                "supplier": "NOASSERTION",
                "versionInfo": packagedata['version'],
                "externalRefs": [{
                    "referenceCategory": "PACKAGE_MANAGER",
                    "referenceType" :"purl",
                    "referenceLocator": f"{referenceLocator}/{name}@{packagedata['version']}"
                }]
            }
            sbom["packages"].append(package_spdx)

            sbom["relationships"].append({
                "spdxElementId": spdx_id,
                "relatedSpdxElement": "SPDXRef-File-AnsiblePlaybook",
                "relationshipType": "GENERATED_FROM"
            })
        return sbom

def main():
    parser = argparse.ArgumentParser(description="Generate SBOM for ansible playbook packages")
    parser.add_argument('playbook', help='Path to playbook')

    args = parser.parse_args()


    ansibleParser = AnsibleParser(args.playbook)
    ansibleParser.parse_ansible_playbook()

    sbom = ansibleParser.generate_spdx()

    
    script_path = Path(os.path.realpath(__file__))
    output_dir = script_path.parent / "output"
    os.makedirs(output_dir)

    with open(output_dir / "ansible-spdx.json", "w") as fp:
        json.dump(sbom, fp)

if __name__ == '__main__':
    main()
