#!/usr/bin/env python3
import argparse
import os
import string
import random
import re
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.devtestlabs import DevTestLabsClient
from azure.mgmt.devtestlabs.models import Schedule
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.resource.subscriptions import SubscriptionClient
from datetime import datetime
from pathlib import Path


def generate_password(length=12):
    uppercase_letters = string.ascii_uppercase
    lowercase_letters = string.ascii_lowercase
    digits = string.digits
    # special_chars = string.punctuation

    # Generate the password with required character types
    password = []
    password.append(random.choice(uppercase_letters))
    password.append(random.choice(lowercase_letters))
    password.append(random.choice(digits))
    #password.append(random.choice(special_chars))

    # Generate the remaining characters (3 chars added above, so subtract 3)
    remaining_length = length - 3
    remaining_chars = uppercase_letters + lowercase_letters + digits 
    password.extend(random.choices(remaining_chars, k=remaining_length))

    # Shuffle the password characters randomly
    random.shuffle(password)

    return "".join(password)


def get_default_subscription_id(credential=None):
    if credential is None:
        credential = DefaultAzureCredential()

    """Get the default subscription ID from Azure environment"""
    subscription_client = SubscriptionClient(credential)
    subscription_list = list(subscription_client.subscriptions.list())
    if not subscription_list:
        raise Exception("No Azure subscriptions found")

    # Use the first subscription in the list
    return subscription_list[0].subscription_id



def create_clients(subscription_id):
    credential = DefaultAzureCredential()
    if subscription_id is None:
        subscription_id = get_default_subscription_id(credential)
    resource_client = ResourceManagementClient(credential, subscription_id)
    network_client = NetworkManagementClient(credential, subscription_id)
    compute_client = ComputeManagementClient(credential, subscription_id)
    devtestlabs_client = DevTestLabsClient(credential, subscription_id)
    return (resource_client, network_client, compute_client,
            devtestlabs_client, subscription_id)


def check_ports_protocals_and_priorities(ports, priorities, protocols):
    if len(ports) != len(priorities):
        print("Priorities and Ports length should be equal!")
        exit(1)
    if len(ports) != len(protocols):
        print("Protocols and Ports length should be equal!")
        exit(1)


def set_network_rules(
    network_client,
    resource_group,
    allowed_sources_list,
    nsg_name,
    ports,
    priorities,
    protocols,
):
    check_ports_protocals_and_priorities(ports, priorities, protocols)

    for i in range(len(ports)):
        port = ports[i]
        priority = priorities[i]
        protocol = protocols[i]
        print(f"\nCreating Network Port {port} rule...")

        nsg_rule_params = {
            "protocol": protocol,
            "source_address_prefix": allowed_sources_list,
            "destination_address_prefix": "*",
            "access": "Allow",
            "direction": "Inbound",
            "source_port_range": "*",
            "destination_port_range": str(port),
            "priority": priority,
            "name": f"Network_Port_Rule_{port}",
        }

        nsg_rule_poller = network_client.security_rules.begin_create_or_update(
            resource_group_name=resource_group,
            network_security_group_name=nsg_name,
            security_rule_name=nsg_rule_params["name"],
            security_rule_parameters=nsg_rule_params,
        )
        nsg_rule = nsg_rule_poller.result()
        print(f"Network rule '{nsg_rule.name}' created successfully.")



def create_public_ip(network_client, resource_group, location, machine_name):
    print(f"\nCreating public IP address for {machine_name}")
    
    # Generate a valid domain name label
    base_name = re.sub(r'[^a-z0-9-]', '', machine_name.lower())
    if not base_name[0].isalpha():
        base_name = 'ip-' + base_name
    unique_dns_name = f"{base_name}-{random.randint(1000, 9999)}"
    unique_dns_name = unique_dns_name[:63]  # Ensure it's not longer than 63 characters
    
    public_ip_params = {
        "location": location,
        "public_ip_allocation_method": "Static",
        "dns_settings": {
            "domain_name_label": unique_dns_name
        },
    }
    public_ip_poller = (
        network_client.public_ip_addresses
        .begin_create_or_update(
            resource_group.name,
            f"{machine_name}-public-ip",
            public_ip_params
        )
    )
    public_ip = public_ip_poller.result()
    print(
        f"Public IP address '{public_ip.name}' with "
        f"ip {public_ip.ip_address} created successfully."
    )
    return public_ip


def create_network_interface(
        network_client, resource_group, location, machine_name,
        subnet_id, private_ip_address, public_ip, nsg_id
        ):
    print(f"\nCreating network interface for {machine_name}...")
    nic_params = {
        "location": location,
        "ip_configurations": [
            {
                "name": f"{machine_name}-ipconfig",
                "subnet": {"id": subnet_id},
                "private_ip_address": private_ip_address,
                "private_ip_allocation_method": "Static",
                "public_ip_address": {
                    "id": public_ip.id
                }
            }
        ],
        "network_security_group": {
            "id": nsg_id
        }
    }
    nic_poller = network_client.network_interfaces.begin_create_or_update(
        resource_group.name, f"{machine_name}-nic", nic_params
    )
    nic = nic_poller.result()
    print(f"Network interface '{nic.name}' created successfully with associated NSG.")
    return nic


def set_auto_shutdown(
        devtestlabs_client, subscription_id, resource_group_name, location,
        vm_name, auto_shutdown_time, auto_shutdown_email
        ):
    print(
            f"\nCreating Auto-Shutdown Rule for {vm_name} "
            f"at time {auto_shutdown_time}...")
    schedule_name = f"shutdown-computevm-{vm_name}"

    schedule_params = Schedule(
        status="Enabled",
        task_type="ComputeVmShutdownTask",
        daily_recurrence={"time": auto_shutdown_time},
        time_zone_id="UTC",
        notification_settings={
            "status": "Enabled" if auto_shutdown_email else "Disabled",
            "time_in_minutes": 30,
            "webhook_url": None,
            "email_recipient": auto_shutdown_email,
        },
        target_resource_id=(
            f"/subscriptions/{subscription_id}/resourceGroups/"
            f"{resource_group_name}/providers/Microsoft.Compute/"
            f"virtualMachines/{vm_name}"
            ),
        location=location,
    )

    devtestlabs_client.global_schedules.create_or_update(
        resource_group_name, schedule_name, schedule_params
    )
    print(f"Auto-Shutdown Rule for {vm_name} created successfully.")


def save_to_parent_directory(filename, content):
    script_dir = Path(__file__).resolve().parent
    parent_dir = script_dir.parent
    file_path = parent_dir / filename
    with open(file_path, "w") as file:
        file.write(content)
    print(f"File saved: {file_path}")


def create_windows_server(
    compute_client,
    network_client,
    resource_group,
    location,
    vm_admin,
    vm_password,
    vnet_name,
    subnet_name,
    nsg_name,
    project,
    today,
    current_user,
    subscription_id  
):
    server_name = "ws1"  
    print(f"\nCreating Windows Server {server_name}...")

    # Create public IP address using the existing function
    public_ip = create_public_ip(network_client, resource_group, location, server_name)

    # Create NIC using the existing function
    subnet_id = (
        f"/subscriptions/{subscription_id}/"
        f"resourceGroups/{resource_group.name}/"
        f"providers/Microsoft.Network/"
        f"virtualNetworks/{vnet_name}/"
        f"subnets/{subnet_name}"
    )
    nsg = network_client.network_security_groups.get(resource_group.name, nsg_name)
    nic = create_network_interface(
        network_client,
        resource_group,
        location,
        server_name,
        subnet_id,
        "10.1.0.4",  
        public_ip,
        nsg.id
    )

    # Create VM
    vm_params = {
        'location': location,
        'os_profile': {
            'computer_name': server_name,
            'admin_username': vm_admin,
            'admin_password': vm_password
        },
        'hardware_profile': {
            'vm_size': 'Standard_DS1_v2'  # Default size, change if needed
        },
        'storage_profile': {
            'image_reference': {
                'publisher': 'MicrosoftWindowsServer',
                'offer': 'WindowsServer',
                'sku': '2019-Datacenter',
                'version': 'latest'
            },
        },
        'network_profile': {
            'network_interfaces': [{
                'id': nic.id,
            }]
        },
        'tags': {
            'project': project,
            'created': today,
            'createdBy': current_user
        }
    }

    try:
        vm_result = compute_client.virtual_machines.begin_create_or_update(
            resource_group.name,
            server_name,
            vm_params
        ).result()
        print(f"Windows Server {server_name} created successfully.")
        return server_name
    except Exception as e:
        print(f"Error creating Windows Server: {str(e)}")
        return None


# All arguments are keyword arguments
def main(
    *,
    resource_group: str,
    location: str,
    allowed_sources: str,
    no_prompt: bool,
    subscription_id: str = None,
    vnet_name: str,
    vnet_prefix: str,
    subnet_name: str,
    subnet_prefix: str,
    ls_ip: str,
    vm_admin: str,
    machine_name: str,
    ports: list[int],
    priorities: list[int],
    protocols: list[str],
    vm_size: str,
    image_publisher: str,
    image_offer: str,
    image_sku: str,
    image_version: str,
    os_disk_size_gb: int,
    auto_shutdown_time: str = None,
    auto_shutdown_email: str = None,
    add_windows_server: bool = False,
):
    (
        resource_client,
        network_client,
        compute_client,
        devtestlabs_client,
        subscription_id
    ) = create_clients(subscription_id)

    # Variables used for Azure tags
    current_user = os.getenv("USER", "unknown")
    today = datetime.now().strftime("%Y-%m-%d")
    project = "LME"

    # Validation of Globals
    allowed_sources_list = allowed_sources.split(",")
    if len(allowed_sources_list) < 1:
        print(
            "**ERROR**: Variable AllowedSources must "
            "be set (set with -AllowedSources or -s)"
        )
        exit(1)

    # Confirmation
    print("Supplied configuration:\n")

    print(f"Location: {location}")
    print(f"Resource group: {resource_group}")
    print(f"Allowed sources (IP's): {allowed_sources_list}")

    if not no_prompt:
        proceed = input("\nProceed? (Y/n) ")
        while proceed.lower() not in ["y", "n"]:
            proceed = input("\nProceed? (Y/n) ")

        if proceed.lower() == "n":
            print("Setup canceled")
            exit()

    # Setup resource group
    print("\nCreating resource group...")
    resource_group_params = {
        "location": location,
        "tags": {
            "user": current_user,
            "created_on": today,
            "project": project,
        },
    }
    resource_group = resource_client.resource_groups.create_or_update(
        resource_group, resource_group_params
    )
    print(f"Resource group '{resource_group.name}' created successfully.")

    # Setup network
    print("\nCreating virtual network...")
    vnet_params = {
        "location": location,
        "address_space": {"address_prefixes": [vnet_prefix]},
        "subnets": [{"name": subnet_name, "address_prefix": subnet_prefix}],
        "tags": {
            "user": current_user,
            "created_on": today,
            "project": project,
        },
    }
    vnet_poller = network_client.virtual_networks.begin_create_or_update(
        resource_group_name=resource_group.name,
        virtual_network_name=vnet_name,
        parameters=vnet_params,
    )
    vnet = vnet_poller.result()
    print(f"Virtual network '{vnet.name}' created successfully.")

    print("\nCreating network security group...")
    nsg_params = {
        "location": location,
        "tags": {
            "user": current_user,
            "created_on": today,
            "project": project,
        },
    }
    nsg_poller = network_client.network_security_groups.begin_create_or_update(
        resource_group_name=resource_group.name,
        network_security_group_name="NSG1",
        parameters=nsg_params,
    )
    nsg = nsg_poller.result()
    print(f"Network security group '{nsg.name}' created successfully.")

    set_network_rules(
        network_client,
        resource_group.name,
        allowed_sources,
        nsg.name,
        ports,
        priorities,
        protocols,
    )


    # Create the VM
    vm_password = generate_password()

    print(
        f"\nWriting {vm_admin} password to {resource_group.name}.password.txt"
    )
    save_to_parent_directory(
            f"{resource_group.name}.password.txt", vm_password
    )

    subnet_id = (
            f"/subscriptions/{subscription_id}/"
            f"resourceGroups/{resource_group.name}/"
            f"providers/Microsoft.Network/"
            f"virtualNetworks/{vnet_name}/"
            f"subnets/{subnet_name}"
            )

    public_ip = create_public_ip(
            network_client, resource_group, location, machine_name
            )

    print(f"\nWriting public_ip to {resource_group.name}.ip.txt")
    save_to_parent_directory(
            f"{resource_group.name}.ip.txt",
            public_ip.ip_address
        )

    nic = create_network_interface(
                network_client,
                resource_group,
                location,
                machine_name,
                subnet_id,
                ls_ip,
                public_ip,
                nsg.id
            )

    print(f"\nCreating {machine_name}...")
    ls1_params = {
        "location": location,
        "hardware_profile": {"vm_size": vm_size},
        "additional_capabilities": {
            "nested_virtualization_enabled": True
        },
        "storage_profile": {
            "image_reference": {
                "publisher": image_publisher,
                "offer": image_offer,
                "sku": image_sku,
                "version": image_version,
            },
            "os_disk": {
                "create_option": "FromImage",
                "disk_size_gb": os_disk_size_gb,
            },
        },
        "os_profile": {
            "computer_name": f"{machine_name}",
            "admin_username": vm_admin,
            "admin_password": f"{vm_password}",
        },
        "network_profile": {
            "network_interfaces": [
                {
                    "id": nic.id,
                }
            ],
        },
        "tags": {
            "user": current_user,
            "created_on": today,
            "project": project,
        },
    }
    ls1_poller = compute_client.virtual_machines.begin_create_or_update(
        resource_group_name=resource_group.name,
        vm_name=machine_name,
        parameters=ls1_params,
    )
    ls1 = ls1_poller.result()
    print(f"Virtual machine '{ls1.name}' created successfully.")

    # Configure Auto-Shutdown
    if auto_shutdown_time:
        set_auto_shutdown(
            devtestlabs_client,
            subscription_id,
            resource_group.name,
            location,
            machine_name,
            auto_shutdown_time,
            auto_shutdown_email
        )

    print("\nVM login info:")
    print(f"ResourceGroup: {resource_group.name}")
    print(f"PublicIP: {public_ip.ip_address}")
    print(f"Username: {vm_admin}")
    print(f"Password: {vm_password}")
    print("SAVE THE ABOVE INFO\n")

    # Add Windows server if the flag is set
    if add_windows_server:
        print("\nAdding Windows server...")
        windows_server = create_windows_server(
            compute_client,
            network_client,
            resource_group,
            location,
            vm_admin,
            vm_password,
            vnet_name,
            subnet_name,
            "NSG1",  # nsg_name
            project,
            today,
            current_user,
            subscription_id  
        )
        if windows_server:
            print(f"Windows Server {windows_server} created successfully.")
        else:
            print("Failed to create Windows Server.")

    print("Done.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Setup Testbed for LME")
    parser.add_argument(
        "-l",
        "--location",
        default="westus",
        help="Location where the cluster will be built. Default westus",
    )
    parser.add_argument(
        "-g", "--resource-group", required=True, help="Resource group name"
    )
    parser.add_argument(
        "-s",
        "--allowed-sources",
        required=True,
        help="XX.XX.XX.XX/YY,XX.XX.XX.XX/YY,etc... Comma-separated "
             "list of CIDR prefixes or IP ranges",
    )
    parser.add_argument(
        "-y",
        "--no-prompt",
        action="store_true",
        help="Run the script with no prompt (useful for automated runs)",
    )
    parser.add_argument(
        "-sid",
        "--subscription-id",
        help="Azure subscription ID. If not provided, "
             "the default subscription ID will be used.",
    )
    parser.add_argument(
        "-vn",
        "--vnet-name",
        default="VNet1",
        help="Virtual network name. Default: VNet1",
    )
    parser.add_argument(
        "-vp",
        "--vnet-prefix",
        default="10.1.0.0/16",
        help="Virtual network prefix. Default: 10.1.0.0/16",
    )
    parser.add_argument(
        "-sn", "--subnet-name",
        default="SNet1",
        help="Subnet name. Default: SNet1"
    )
    parser.add_argument(
        "-sp",
        "--subnet-prefix",
        default="10.1.0.0/24",
        help="Subnet prefix. Default: 10.1.0.0/24",
    )
    parser.add_argument(
        "-ip",
        "--ls-ip",
        default="10.1.0.5",
        help="IP address for the VM. Default: 10.1.0.5",
    )
    parser.add_argument(
        "-u",
        "--vm-admin",
        default="lme-user",
        help="Admin username for the VM. Default: lme-user",
    )
    parser.add_argument(
        "-m", "--machine-name",
        default="ubuntu",
        help="Name of the VM. Default: ubuntu"
    )
    parser.add_argument(
        "-p",
        "--ports",
        type=int,
        nargs="+",
        default=[22, 443, 5601, 9200, 9001],
        help="Ports to open. Default: [22, 443, 5601, 9200, 9001]",
    )
    parser.add_argument(
        "-pr",
        "--priorities",
        type=int,
        nargs="+",
        default=[1001, 1002, 1003, 1004, 1005],
        help="Priorities for the ports. Default: [1001, 1002, 1003, 1004, 1005]",
    )
    parser.add_argument(
        "-pt",
        "--protocols",
        nargs="+",
        default=["Tcp", "Tcp", "Tcp", "Tcp", "Tcp"],
        help="Protocols for the ports. Default: ['Tcp', 'Tcp', 'Tcp', 'Tcp', 'Tcp']",
    )
    parser.add_argument(
        "-vs",
        "--vm-size",
        default="Standard_E2d_v4",
        help="Size of the virtual machine. Default: Standard_E2d_v4",
        # Standard_D8_v4 for testing minimega and a linux install of LME
        # Standard_D16d_v4 is the smallest VM size that we can get away
        #  with for minimega to include all the machines
    )
    parser.add_argument(
        "-pub",
        "--image-publisher",
        default="Canonical",
        help="Publisher of the VM image. Default: Canonical",
    )
    parser.add_argument(
        "-io",
        "--image-offer",
        default="0001-com-ubuntu-server-jammy",
        help="Offer of the VM image. Default: 0001-com-ubuntu-server-jammy",
    )
    parser.add_argument(
        "-is",
        "--image-sku",
        default="22_04-lts-gen2",
        help="SKU of the VM image. Default: 22_04-lts-gen2",
    )
    #  ubuntu-24_04-lts
    parser.add_argument(
        "-iv",
        "--image-version",
        default="latest",
        help="Version of the VM image. Default: latest",
    )
    parser.add_argument(
        "-os",
        "--os-disk-size-gb",
        type=int,
        default=128,
        help="Size of the OS disk in GB. Default: 128",
    )
    parser.add_argument(
        "-ast",
        "--auto-shutdown-time",
        help="Auto-Shutdown time in UTC (HH:MM, e.g. 22:30, 00:00, 19:00). "
             "Convert timezone as necessary.",
    )
    parser.add_argument(
        "-ase",
        "--auto-shutdown-email",
        help="Auto-shutdown notification email",
    )
    parser.add_argument(
        "-w",
        "--add-windows-server",
        action="store_true",
        help="Add a Windows server with default settings",
    )
    parser.add_argument(
        "--use-rhel",
        action="store_true",
        help="Use Red Hat Enterprise Linux 9 instead of Ubuntu 22.04",
    )

    args = parser.parse_args()
    
    # Override image parameters if RHEL is requested
    if args.use_rhel:
        # Only override if user didn't specify custom values
        if args.image_publisher == "Canonical":
            args.image_publisher = "RedHat"
        if args.image_offer == "0001-com-ubuntu-server-jammy":
            args.image_offer = "RHEL"
        if args.image_sku == "22_04-lts-gen2":
            args.image_sku = "9-lvm-gen2"
        args.machine_name = "rhel" if args.machine_name == "ubuntu" else args.machine_name
        print(f"Using Red Hat Enterprise Linux image: {args.image_publisher}:{args.image_offer}:{args.image_sku}")
    else:
        # Detect Ubuntu version based on image parameters
        if args.image_offer == "ubuntu-24_04-lts" or "24" in args.image_sku:
            print(f"Using Ubuntu 24.04 image: {args.image_publisher}:{args.image_offer}:{args.image_sku}")
        elif args.image_offer == "0001-com-ubuntu-server-jammy" or "22" in args.image_sku:
            print(f"Using Ubuntu 22.04 image: {args.image_publisher}:{args.image_offer}:{args.image_sku}")
        else:
            print(f"Using Ubuntu image: {args.image_publisher}:{args.image_offer}:{args.image_sku}")
    
    check_ports_protocals_and_priorities(
            args.ports, args.priorities, args.protocols
        )

    main(
        resource_group=args.resource_group,
        location=args.location,
        allowed_sources=args.allowed_sources,
        no_prompt=args.no_prompt,
        subscription_id=args.subscription_id,
        vnet_name=args.vnet_name,
        vnet_prefix=args.vnet_prefix,
        subnet_name=args.subnet_name,
        subnet_prefix=args.subnet_prefix,
        ls_ip=args.ls_ip,
        vm_admin=args.vm_admin,
        machine_name=args.machine_name,
        ports=args.ports,
        priorities=args.priorities,
        protocols=args.protocols,
        vm_size=args.vm_size,
        image_publisher=args.image_publisher,
        image_offer=args.image_offer,
        image_sku=args.image_sku,
        image_version=args.image_version,
        os_disk_size_gb=args.os_disk_size_gb,
        auto_shutdown_time=args.auto_shutdown_time,
        auto_shutdown_email=args.auto_shutdown_email,
        add_windows_server=args.add_windows_server,
    )
