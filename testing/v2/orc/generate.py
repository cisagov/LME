#!/usr/bin/env python3

import argparse
import os
import random
import string
import ipaddress
import subprocess

import yaml

#give me a function to generate a mac address string that increments itself
def generate_mac_address():
    mac = [random.randint(0x00, 0xff) for _ in range(6)]
    return ':'.join(['%02x' % x for x in mac])

def generate_random_string(length=8):
    """Generate an 8-character random string."""
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

def generate_ssh_key_pair(key_path):
    """Generate an RSA key pair using ssh-keygen."""
    subprocess.run(
        ["ssh-keygen", "-t", "rsa", "-b", "4096", "-f", key_path, "-N", ""],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    with open(key_path, "r") as f:
        private_key = f.read().strip()
    with open(f"{key_path}.pub", "r") as f:
        public_key = f.read().strip()
    os.remove(f"{key_path}.pub")
    return private_key, public_key

def _setup(windows_count, linux_count, network_cidr, state_dir):
    """
    Perform the initial environment preparation shared by
    ``generate_inventory_vars_and_scripts``.
    Returns a dictionary containing all values needed later in the workflow.
    """
    network = ipaddress.ip_network(network_cidr, strict=False)
    ip_list = list(network.hosts())
    gateway = ip_list[0]

    # experiment id:
    random_str = generate_random_string()
    if state_dir is not None:
        # If a state_dir is provided, ensure it exists as a directory.
        if os.path.exists(state_dir):
            if not os.path.isdir(state_dir):
                raise NotADirectoryError(
                    f"Provided state_dir path exists but is not a directory: {state_dir}"
                )
        else:
            try:
                os.makedirs(state_dir, exist_ok=False)
            except OSError as e:
                raise OSError(
                    f"Failed to create state_dir '{state_dir}': {e.strerror}"
                ) from e
        experiment_dir = state_dir
    else:
        experiment_dir = f"state_{random_str}"
        # create a directory of state_{random_str}, if it does not exist, if it does exist raise an error
        if os.path.exists(experiment_dir):
            raise Exception(f"Directory {experiment_dir} already exists")
        else:
            os.makedirs(experiment_dir)

    # logic check
    available_ips = [ip for ip in ip_list if ip != gateway]
    if len(available_ips) < (windows_count + linux_count):
        raise ValueError(
            f"Not enough IPs in {network_cidr} for {windows_count + linux_count} hosts"
        )

    # ansible ssh key
    linux_key_path = os.path.join(experiment_dir, "linux_key")
    linux_private_key, linux_public_key = generate_ssh_key_pair(linux_key_path)
    os.chmod(linux_key_path, 0o600)

    return {
        "network": network,
        "ip_list": ip_list,
        "gateway": gateway,
        "random_str": random_str,
        "experiment_dir": experiment_dir,
        "available_ips": available_ips,
        "linux_key_path": linux_key_path,
        "linux_private_key": linux_private_key,
        "linux_public_key": linux_public_key,
    }

def generate_inventory_vars_and_scripts(windows_count, linux_count, network_cidr, state_dir=None,
                                        windows_user="localuser", windows_password="password",
                                        linux_user="localuser", linux_password="password",
                                        memory=8192, cpu=4):
    """
Generate state_{experiment_id}:
    - ansible_deployment: hosts.yml, vars.yml
    - ip_addr assignment: dnsmasq.mm
    - mac_address for ip_mapping: network.mm"""

    # ---------------------------------------------------------------------
    # Initial setup – moved to a dedicated helper to keep cyclomatic complexity low
    # ---------------------------------------------------------------------
    setup_data = _setup(windows_count, linux_count, network_cidr, state_dir)

    network = setup_data["network"]
    ip_list = setup_data["ip_list"]
    gateway = setup_data["gateway"]
    random_str = setup_data["random_str"]
    experiment_dir = setup_data["experiment_dir"]
    available_ips = setup_data["available_ips"]
    linux_key_path = setup_data["linux_key_path"]
    # linux_private_key and linux_public_key are generated for completeness but not used further
    # linux_private_key = setup_data["linux_private_key"]
    # linux_public_key = setup_data["linux_public_key"]


    # ---------------------------------------------------------------------
    # Build inventory data structures – split into small helpers to keep the
    # main function's cyclomatic complexity low.
    # ---------------------------------------------------------------------
    hosts_data = {
        "all": {
            "children": {
                "linux": {"hosts": {}},
                "windows": {"hosts": {}},
            }
        }
    }

    # Helper to add a host entry to the given group
    def _add_host(group: str, ip_addr: str, data: dict) -> None:
        hosts_data["all"]["children"][group]["hosts"][ip_addr] = data

    used_ips: set[str] = set()

    # 1 LME_BOX – first Linux host
    lme_ip = str(available_ips[0])
    used_ips.add(lme_ip)
    _add_host(
        "linux",
        lme_ip,
        {
            "ansible_user": "localuser",
            "ansible_ssh_password": "password",
            "ansible_ssh_private_key_file": linux_key_path,
            "desired_hostname": "lme",
        },
    )

    # 2 Additional Linux hosts (skip the LME IP)
    for i in range(1, linux_count):
        ip_addr = str(available_ips[i])
        used_ips.add(ip_addr)
        _add_host(
            "linux",
            ip_addr,
            {
                "ansible_user": "localuser",
                "ansible_ssh_password": "password",
                "ansible_ssh_private_key_file": linux_key_path,
                "hostname": f"lin{i}",
            },
        )

    # 3 Windows hosts
    for i in range(windows_count):
        ip_addr = str(available_ips[linux_count + i])
        used_ips.add(ip_addr)
        _add_host(
            "windows",
            ip_addr,
            {
                "ansible_user": "localuser",
                "ansible_ssh_password": "password",
                "hostname": f"win{i+1}",
            },
        )

    # 4 Caldera host – first free IP after the used … 
    caldera_ip = next((str(c) for c in available_ips if str(c) not in used_ips), None)
    if caldera_ip is None:
        raise RuntimeError("Unable to allocate IP for caldera host")
    _add_host(
        "linux",
        caldera_ip,
        {
            "ansible_user": "localuser",
            "ansible_ssh_password": "password",
            "ansible_ssh_private_key_file": linux_key_path,
            "hostname": "caldera",
        },
    )

    vars_data = {
        "gateway": str(gateway),
        "nameserver": str(gateway),
        "experiment_id": random_str
    }

    # Also save copies inside the experiment directory
    hosts_path = os.path.join(experiment_dir, "hosts.yml")
    vars_path = os.path.join(experiment_dir, "vars.yml")
    inventory_path = os.path.join(experiment_dir, "inventory.ini")
    with open(hosts_path, "w") as f:
        yaml.dump(hosts_data, f, default_flow_style=False)
    with open(vars_path, "w") as f:
        yaml.dump(vars_data, f, default_flow_style=False)

    #TODO: make these cli params
    # Define the base path for VM files (adjust as needed)
    # Define the base directory for VM files (adjust as needed)
    files_base = os.path.expanduser("~/files")
    network_name = "EXP"

    # Directory containing the Windows QCOW image
    qcow_dir_name = "win11-23h2-x64-enterprise-gold"
    qcow_directory_path = os.path.abspath(os.path.join(files_base, qcow_dir_name))
    qcow_path = os.path.join(qcow_directory_path, qcow_dir_name)

    #print(f"QCOW directory: {qcow_directory_path}")
    #print(f"QCOW path: {qcow_path}")

    #toggle ovmf settings
    if os.path.exists("/usr/share/OVMF/OVMF_CODE_4M.fd"):
        OVMF_PATH = "/usr/share/OVMF/OVMF_CODE_4M.fd"
    else:
        OVMF_PATH = "/usr/share/OVMF/OVMF_CODE.fd"

    # Ensure the mm directory exists
    mm_dir = os.path.join(experiment_dir, "mm")
    os.makedirs(mm_dir, exist_ok=True)

    # Generate configuration snippets for each Windows VM
    for ip, data in hosts_data["all"]["children"]["windows"]["hosts"].items():
        vm_name = data.get("hostname") or ip
        vm_config = f"""#windows
clear vm config
vm config disk {qcow_path}
vm config snapshot true
vm config memory {memory}
vm config vcpus {cpu}
vm config machine q35

vm config qemu-append -drive file={OVMF_PATH},if=pflash,unit=0,format=raw,readonly=on -drive file={qcow_directory_path}/efivars.fd,if=pflash,unit=1,format=raw

vm config net {network_name}
vm launch kvm {vm_name}
"""
        vm_file_path = os.path.join(mm_dir, f"{vm_name}.mm")
        with open(vm_file_path, "w") as vm_file:
            vm_file.write(vm_config)

    # Generate configuration snippets for each Linux VM
    for ip, data in hosts_data["all"]["children"]["linux"]["hosts"].items():
        vm_name = data.get("hostname") or data.get("desired_hostname") or ip
        vm_config = f"""#linux
clear vm config
vm config disk {qcow_path}
vm config snapshot true
vm config memory {memory}
vm config vcpus {cpu}
vm config net {network_name}
vm launch kvm {vm_name}
"""
        vm_file_path = os.path.join(mm_dir, f"{vm_name}.mm")
        with open(vm_file_path, "w") as vm_file:
            vm_file.write(vm_config)

    # ---------------------------------------------------------------------
    # Generate a simple Ansible inventory file (INI format)
    # ---------------------------------------------------------------------
    def _format_host(entry_ip: str, entry_data: dict) -> str:
        """
        Return a formatted inventory line for a host.
        """
        hostname = entry_data.get("hostname") or entry_data.get("desired_hostname") or entry_ip
        parts = [f"{hostname}", f"ansible_host={entry_ip}"]
        if "ansible_ssh_private_key_file" in entry_data:
            parts.append("ansible_user=localuser")
            parts.append(f"ansible_ssh_private_key_file={entry_data['ansible_ssh_private_key_file']}")
        else:
            parts.append("ansible_user=localuser")
            parts.append("ansible_password=password")
        return " ".join(parts)

    with open(inventory_path, "w") as f:
        f.write("[lme_servers]\n")
        for ip, data in hosts_data["all"]["children"]["linux"]["hosts"].items():
            f.write(_format_host(ip, data) + "\n")
        f.write("\n")
        f.write("[windows]\n")
        for ip, data in hosts_data["all"]["children"]["windows"]["hosts"].items():
            f.write(_format_host(ip, data) + "\n")
        f.write("\n")
        f.write("[windows:vars]\n")
        f.write("ansible_user=localuser\n")
        f.write("ansible_password=password\n")
        f.write("ansible_connection=winrm\n")
        f.write("ansible_winrm_transport=basic\n")
        f.write("ansible_port=5986\n")
        f.write("ansible_winrm_scheme=https\n")
        f.write("ansible_winrm_server_cert_validation=ignore\n")
        f.write("\n")
        f.write("[lme_servers:vars]\n")
        f.write("ansible_ssh_common_args='-o StrictHostKeyChecking=no'\n")

    logging.debug(f"Generated hosts.yml, vars.yml, and inventory.ini in {experiment_dir} (experiment ID: {random_str})")
    logging.debug(f"SSH keys generated: {linux_key_path} (Linux)")
    logging.info(f"Generated Experiment in {experiment_dir}")


def main():
    """
    generate ansible and ludus configurations with ssh keys

    Example running:
    python3 generate.py --windows 2 --linux 3 --network 192.168.0.0/24 --gateway 192.168.0.1 --priv_dir ./keys --script_dir init_scripts --ludus_network my_network --role_config_dir ludus_roles
    """
    parser = argparse.ArgumentParser(description=main.__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--windows", type=int, required=True, help="Number of Windows clients")
    parser.add_argument("--linux", type=int, required=True, help="Number of Linux clients")
    parser.add_argument("--network", type=str, required=True, help="Network CIDR (e.g., 192.168.0.0/24)")
    #parser.add_argument("--gateway", type=str, help="Gateway IP (defaults to first usable IP)")
    parser.add_argument("--state_dir", type=str, default=None, help="Directory for init scripts")
    parser.add_argument(
        "--files_path",
        type=str,
        default=os.path.join(os.environ.get("HOME", "~"), "files"),
        help="Base directory under which VM disk trees live (default: $HOME/files)",
    )
    parser.add_argument(
        "--memory",
        type=int,
        default=8192,
        help="Memory in MB for each VM (default: 8192)",
    )
    parser.add_argument(
        "--cpu",
        type=int,
        default=4,
        help="vCPUs per VM (default: 4)",
    )
    args = parser.parse_args()

    if subprocess.run(["which", "ssh-keygen"], stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode != 0:
        raise RuntimeError("ssh-keygen not found. Please install OpenSSH tools.")


    generate_inventory_vars_and_scripts(args.windows, args.linux, args.network, args.state_dir, memory=args.memory, cpu=args.cpu)

if __name__ == "__main__":
    main()
