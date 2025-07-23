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

def generate_inventory_vars_and_scripts(windows_count, linux_count, network_cidr, state_dir=None,
                                        windows_user="localuser", windows_password="password",
                                        linux_user="localuser", linux_password="password"):
    """
Generate state_{experiment_id}: 
    - ansible_deployment: hosts.yml, vars.yml
    - ip_addr assignment: dnsmasq.mm
    - mac_address for ip_mapping: network.mm"""

    network = ipaddress.ip_network(network_cidr, strict=False)
    ip_list = list(network.hosts())
    gateway = ip_list[0]

    #experiment id:
    random_str = generate_random_string()
    experiment_dir = f"state_{random_str}"
    #create a directory of state_{random_str}, if it does not exist, if it does exit and error out
    if os.path.exists(experiment_dir):
        raise Exception(f"Directory {experiment_dir} already exists")
    else:
        os.makedirs(f"{experiment_dir}")

    #logic check 
    available_ips = [ip for ip in ip_list if ip != gateway]
    if len(available_ips) < (windows_count + linux_count):
        raise ValueError(f"Not enough IPs in {network_cidr} for {windows_count + linux_count} hosts")

    #ansible ssh key:
    linux_key_path = os.path.join(experiment_dir, "linux_key")
    linux_private_key, linux_public_key = generate_ssh_key_pair(linux_key_path)
    os.chmod(linux_key_path, 0o600)

    hosts_data = {
        "all": {
            "children": {
                "linux": {"hosts": {}},
                "windows": {"hosts": {}}
            }
        }
    }


    #LME_BOX
    ip = str(available_ips[0])
    hostname = f"lme"
    hosts_data["all"]["children"]["linux"]["hosts"][ip] = {
        "ansible_user": "localuser",
        "ansible_password": "password",
        "ansible_ssh_private_key_file": linux_key_path,
        "desired_hostname": hostname
    }

    #skip first ip for LME_BOX
    for i in range(linux_count)[1:]:
        ip = str(available_ips[i])
        hostname = f"lin{i+1}-{random_str}"
        hosts_data["all"]["children"]["linux"]["hosts"][ip] = {
            "ansible_user": "localuser",
            "ansible_password": "password",
            "ansible_ssh_private_key_file": linux_key_path,
            "hostname": hostname
        }


    for i in range(windows_count):
        ip = str(available_ips[linux_count + i])
        hostname = f"win{i+1}-{random_str}"
        hosts_data["all"]["children"]["windows"]["hosts"][ip] = {
            "ansible_user": "localuser",
            "ansible_password": "password",
            "hostname": hostname
        }

    vars_data = {
        "gateway": str(gateway),
        "nameserver": str(gateway),
        "experiment_id": random_str
    }

    with open("hosts.yml", "w") as f:
        yaml.dump(hosts_data, f, default_flow_style=False)
    with open("vars.yml", "w") as f:
        yaml.dump(vars_data, f, default_flow_style=False)

    print(f"Generated hosts.yml, vars.yml:  {experiment_dir} with experiment ID: {random_str}")
    print(f"SSH keys generated: {linux_key_path} (Linux)")

    #create dnsmasq.mm
    dnsmasq_strings = []
    network_strings = []

    #create network.mm


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
    parser.add_argument("--gateway", type=str, help="Gateway IP (defaults to first usable IP)")
    parser.add_argument("--state_dir", type=str, default=None, help="Directory for init scripts")
    args = parser.parse_args()

    if subprocess.run(["which", "ssh-keygen"], stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode != 0:
        raise RuntimeError("ssh-keygen not found. Please install OpenSSH tools.")

    generate_inventory_vars_and_scripts( )

if __name__ == "__main__":
    main()
