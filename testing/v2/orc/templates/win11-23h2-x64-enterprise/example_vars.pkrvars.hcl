# path to files. ensure this path points to lme/orc/files
# ensure this path is correct
proxmox_storage_pool = "../../files"
iso_storage_pool = "../../files/isos"
iso_url = "../../files/isos/win11.iso"

vm_name = "win11"
proxmox_storage_format = "qcow2"
ludus_nat_interface = "experiment"

#if you keep to local the socket path is too long
ansible_home = "/tmp/lme/ansible_state/"
