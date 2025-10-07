import os
import re
import yaml
import uuid
import json
import hashlib
import datetime
import subprocess
from typing import List, Dict
from pathlib import Path

def get_os_version() -> Dict[str, str]:
    #default to "" if we cannot get os info. Would rather
    #have everything in sbom than nothing
    info = { 
        "name": "",
        "version": "",
    }

    release_path = Path("/etc/os-release")
    if not release_path.exists():
        return info

    data = {}
    with open(release_path, 'r') as fp:
        for line in fp.readlines():
            line = line.strip()
            if line and "=" in line:
                key, value = line.split("=", 1)
                data[key] = value


    info["name"] = data.get("NAME", "").strip("\"")
    info["version"] = data.get("VERSION_ID", "").strip("\"")
    
    return info

def get_package_version(package: str, os_info: Dict[str, str]) -> str:
    version = 'unknown'
    
    os_name = os_info.get("name", "").lower()
    
    try:
        # Determine which package manager to use based on OS
        if 'red hat' in os_name or 'rhel' in os_name or 'centos' in os_name or 'fedora' in os_name:
            # Use dnf/yum for Red Hat-based systems
            for cmd in ['dnf', 'yum']:
                try:
                    result = subprocess.run([cmd, 'info', package], capture_output=True, text=True, timeout=10)
                    if result.returncode == 0:
                        version_match = re.search(r'Version\s*:\s*([^\n]+)', result.stdout)
                        if version_match:
                            version = version_match.group(1).strip()
                            break
                except FileNotFoundError:
                    continue
        else:
            # Use apt for Debian/Ubuntu systems
            result = subprocess.run(['apt-cache', 'show', package], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version_match = re.search(r'Version:\s*([^\n]+)', result.stdout)
                if version_match:
                    version = version_match.group(1).strip()
    except(subprocess.TimeoutExpired, subprocess.SubprocessError, FileNotFoundError):
        version = 'unknown'

    return version

class Package():
    def __init__(self, name: str, version: str, file: Path, pkg_type: str, os_info: Dict[str, str] = None):
        self.name = name
        self.version = version
        self.file = file
        self.package_type = pkg_type
        self.os_info = os_info or {}

        self.hash_string = self.make_hash_string()
        self.reference_locator = self.get_reference_locator()
        self.spdx_id = self.get_spdx_id()

    def get_reference_locator(self) -> str:
        reference_locator = "NOASSERTION"
        
        if self.package_type == "rpm":
            # For Red Hat-based systems
            os_name = self.os_info.get("name", "").lower()
            if 'red hat' in os_name or 'rhel' in os_name:
                reference_locator = f"pkg:rpm/redhat/{self.name}"
            elif 'centos' in os_name:
                reference_locator = f"pkg:rpm/centos/{self.name}"
            elif 'fedora' in os_name:
                reference_locator = f"pkg:rpm/fedora/{self.name}"
            else:
                reference_locator = f"pkg:rpm/{self.name}"
        elif self.package_type == "deb":
            # For Debian-based systems
            os_name = self.os_info.get("name", "").lower()
            if 'ubuntu' in os_name:
                reference_locator = f"pkg:deb/ubuntu/{self.name}"
            elif 'debian' in os_name:
                reference_locator = f"pkg:deb/debian/{self.name}"
            else:
                reference_locator = f"pkg:deb/{self.name}"
        elif self.package_type == "nix":
            reference_locator = f"pkg:nix/{self.name}"

        #if version specified, add to reference locator
        if self.version not in ["", "unknown", "NOASSERTION"]:
            reference_locator += f"@{self.version}"
        return reference_locator

    def make_hash_string(self) -> str:
        hash_string = f"{self.name}{self.version}{str(self.file)}"
        hash_obj = hashlib.sha1()
        hash_obj.update(hash_string.encode('utf-8'))
        hash = hash_obj.hexdigest()
        return hash

    def get_spdx_id(self) -> str:
        name = f"{self.name}-{self.hash_string[:10]}"
        spdx_id = f"SPDXRef-Package-{name.replace('-','').replace('_','')}"

        return spdx_id

class SbomPart():
    def __init__(self, root_package_id: str):
        self.root_package_id = root_package_id

        self.files = list()
        self.packages = list()
        self.relationships = list()

    def add_file(self, file_path: Path, base_dir: Path) -> str:
        with open(file_path, 'rb') as fp:
            filedata = fp.read()
            sha_1_hash = hashlib.sha1(filedata).hexdigest()
            sha_256_hash = hashlib.sha256(filedata).hexdigest()

        relative_path = file_path.relative_to(base_dir)
        file_id = '-'.join(relative_path.parts[:-1]) + '-' + relative_path.name.split('.')[0]
        spdx_file_id = f"SPDXRef-File-{file_id}-{sha_1_hash[:10]}"

        self.files.append( {
            "SPDXID": spdx_file_id,
            "fileName": str(file_path),
            "checksums": [
                {"algorithm": "SHA256", "checksumValue": sha_256_hash},
                {"algorithm": "SHA1", "checksumValue": sha_1_hash},
            ],
            "fileTypes": ["SOURCE"],
            "copyrightText": "NOASSERTION"
        })

        self.relationships.append({
            "spdxElementId": self.root_package_id,
            "relatedSpdxElement": spdx_file_id,
            "relationshipType": "DESCRIBES"
        })

        return spdx_file_id

    def add_package(self, package: Package, spdx_file_id: str):
        package_spdx = {
            "SPDXID": package.spdx_id,
            "name": package.name,
            "downloadLocation":"NOASSERTION",
            "filesAnalyzed": False,
            "supplier": "NOASSERTION",
            "versionInfo": package.version,
            "externalRefs": [{
                "referenceCategory": "PACKAGE_MANAGER",
                "referenceType" :"purl",
                "referenceLocator": package.reference_locator
            }]
        }
        self.packages.append(package_spdx)

        self.relationships.append({
            "spdxElementId": package.spdx_id,
            "relatedSpdxElement": spdx_file_id,
            "relationshipType": "GENERATED_FROM"
        })

class Sbom():
    def __init__(self):
        self.root_package_id = "SPDXRef-Package-Document"
        self.data = {
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
        self.data["packages"].append({
            "SPDXID": self.root_package_id,
            "name": "Ansible-Deployment-Root",
            "downloadLocation": "NOASSERTION",
            "filesAnalyzed": False,
        })
        self.data["relationships"].append({
            "spdxElementId": "SPDXRef-DOCUMENT",
            "relatedSpdxElement": self.root_package_id,
            "relationshipType": "DESCRIBES",
        })

    def add_part(self, part: SbomPart):
        self.data["files"].extend(part.files)
        self.data["packages"].extend(part.packages)
        self.data["relationships"].extend(part.relationships)

    def save(self, output_file: Path):
        with open(output_file, 'w') as fp:
            json.dump(self.data, fp)
        print(f"Sbom saved to {output_file}")


class NixPackageParser():
    def __init__(self, path: Path, baseDir: Path):
        self.file_path = path
        self.baseDir = baseDir
        self.nix_packages = set()

        self.package_details: List[Package] = []

        self.parse_ansible_playbook()

    def parse_ansible_playbook(self):
        with open(self.file_path, 'r') as fp:
            playbook = yaml.safe_load(fp)

        if playbook is None:
            return 0

        if type(playbook) == dict:
            playbook = [playbook]

        for task in playbook:
            self.parse_task(task)

    def parse_task(self, task: dict):
        if not ('nix' in task or any('nix' in str(v).lower() for v in task.values() if isinstance(v, str))):
            return

        for _, value in task.items():
            if not ( isinstance(value, str) and 'nix' in value.lower()):
                continue 

            nix_patterns = [
                r'nixpkgs\.([a-zA-Z0-9_-]+)',
                r'nix-env\s+-i\s+([^\s]+)',
            ]

            for pattern in nix_patterns:
                matches = re.findall(pattern, value)
                self.nix_packages.update(matches)

    def make_sbom_data(self, root_package_id: str) -> SbomPart:
        sbom_part = SbomPart(root_package_id)
        spdx_file_id = sbom_part.add_file(self.file_path, self.baseDir)
        for pkg in self.nix_packages:
            p = Package(pkg, "unknown", self.file_path, "nix", {})
            sbom_part.add_package(p, spdx_file_id)
        return sbom_part

class AptPackageSBOMGenerator():
    def __init__(self, filepath: Path, LME_BASE_PATH: Path, os_info = get_os_version()):
        self.filepath = filepath
        self.LME_BASE_PATH = LME_BASE_PATH

        self.package_details: List[Package] = []
        self.os_info = os_info

    def is_valid_release_type(self, release: str) -> bool:
        os_name = self.os_info.get("name", "").lower()
        os_release = self.os_info.get("version", "").lower()
        os_release = os_release.replace(".", "_")

        # print(f"Checking release '{release}' against OS '{os_name}' version '{os_release}'")

        # Always include common packages
        if 'common' in release.lower():
            return True
            
        # Handle Red Hat Enterprise Linux
        if 'red hat' in os_name or 'rhel' in os_name:
            if 'redhat' in release.lower():
                # If there are no numbers in the release name, assume it applies to all versions
                if not re.search(r'\d', release):
                    return True
                # Check for version match (e.g., redhat_9 matches version 9.x)
                major_version = os_release.split('_')[0] if '_' in os_release else os_release.split('.')[0]
                if major_version in release.lower():
                    return True
            return False
            
        # Handle other distributions
        if " " in os_name:
            os_name = os_name.split(" ")[0]  # Take first word (e.g., "red" from "red hat")
            
        if os_name in release.lower():
            # If there are no numbers, assume no version name
            if not re.search(r'\d', release):
                return True
            if os_release in release.lower():
                return True
                
        return False 

    def get_apt_packages_list(self):
        with open(self.filepath, 'r') as fp:
            yaml_data = yaml.safe_load(fp)

        packages = set() 

        for release_type, package_list in yaml_data.items():
            if self.is_valid_release_type(release_type):
                packages.update(package_list)

        # Determine package type based on OS
        os_name = self.os_info.get("name", "").lower()
        if 'red hat' in os_name or 'rhel' in os_name or 'centos' in os_name or 'fedora' in os_name:
            pkg_type = "rpm"
        else:
            pkg_type = "deb"
            
        for package in packages:
            pkg = Package(package, get_package_version(package, self.os_info), self.filepath, pkg_type, self.os_info)
            self.package_details.append(pkg)

    def make_sbom_data(self, root_package_id: str) -> SbomPart:
        #get the file hashes for the sbom
        sbom_part = SbomPart(root_package_id)
        spdx_file_id = sbom_part.add_file(self.filepath, self.LME_BASE_PATH)
        for packageData in self.package_details:
            sbom_part.add_package(packageData, spdx_file_id)

        return sbom_part 

def main():
    script_path = Path(os.path.realpath(__file__))
    base_dir= script_path.parent.parent.parent / "ansible"

    apt_package_list = base_dir/ "roles" / "base" / "defaults" / "main.yml"
    aptPacakge = AptPackageSBOMGenerator(apt_package_list, base_dir)
    aptPacakge.get_apt_packages_list()

    os_info = get_os_version()

    nix_dir = base_dir / "roles" / "nix" / "tasks"
    os_name = os_info.get("name", "").lower()
    
    # Select the appropriate nix file based on OS
    if 'red hat' in os_name or 'rhel' in os_name:
        nix_file_path = nix_dir / "redhat.yml"
    elif 'ubuntu' in os_name:
        nix_file_path = nix_dir / "ubuntu.yml"
    elif 'debian' in os_name:
        nix_file_path = nix_dir / "debian.yml"
    else:
        # Default to common if no specific match
        nix_file_path = nix_dir / "common.yml"

    nixParser = NixPackageParser(nix_file_path, base_dir)

    full_sbom = Sbom()
    full_sbom.add_part(aptPacakge.make_sbom_data(full_sbom.root_package_id))
    full_sbom.add_part(nixParser.make_sbom_data(full_sbom.root_package_id))

    output_dir = script_path.parent / "output"
    os.makedirs(output_dir, exist_ok=True)

    full_sbom.save(output_dir / "ansible-spdx.json")

if __name__ == '__main__':
    main()
