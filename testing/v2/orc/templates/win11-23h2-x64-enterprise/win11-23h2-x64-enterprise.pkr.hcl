variable "iso_checksum" {
  type    = string
  default = "sha256:c8dbc96b61d04c8b01faf6ce0794fdf33965c7b350eaa3eb1e6697019902945c"
}

variable "iso_url" {
  type    = string
}

variable "vm_cpu_cores" {
  type    = string
  default = "4"
}

variable "vm_disk_size" {
  type    = string
  default = "100G"
}

variable "vm_memory" {
  type    = string
  default = "8192"
}

variable "vm_name" {
  type    = string
  default = "win11-23h2-x64-enterprise-gold"
}

variable "winrm_password" {
  type    = string
  default = "password"
}

variable "winrm_username" {
  type    = string
  default = "localuser"
}

# This block has to be in each file or packer won't be able to use the variables
variable "proxmox_storage_pool" {
  type = string
}
variable "proxmox_storage_format" {
  type = string
  default = "qcow2"
}
variable "iso_storage_pool" {
  type = string
}

source "qemu" "win11-23h2-x64-enterprise" {
  #boot things:
  boot_wait        = "-1s"
  # Hit the "Press any key to boot from CD ROM"
  boot_command = [  # 120 seconds of enters to cover all different speeds of disks as windows boots
    "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>",
  #  "<return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait><return><wait>"
  ]

	#isos/setup:	
  #iso_checksum     = "${var.iso_checksum}"
  iso_checksum = "none" #TODO: delete after debugging
  iso_url          = "${var.iso_url}"
	cd_files = [
		"iso/setup-for-ansible.ps1",
		"iso/win-updates.ps1",
		"iso/windows-common-setup.ps1",
		"Autounattend.xml",
    "${var.iso_storage_pool}/virtio-drivers/*"
	]

	#processor settings
  efi_boot         = true
  efi_firmware_code = "/usr/share/OVMF/OVMF_CODE.fd" #TODO: might use OVMF_CODE_4M
  efi_firmware_vars = "/usr/share/OVMF/OVMF_VARS.fd" #TODO: might use OVMF_CODE_4M
  headless         = true
  accelerator      = "kvm"
  machine_type     = "q35"
  qemu_binary      = "/usr/bin/qemu-system-x86_64"
  cpu_model = "host"
  
	#booting vm:
  disk_size        = "${var.vm_disk_size}"
	format            = "${var.proxmox_storage_format}"
  cpus             = "${var.vm_cpu_cores}"
  memory           = "${var.vm_memory}"

  #disk sotrage:
  output_directory = "${var.proxmox_storage_pool}/${var.vm_name}"
  vm_name          = "${var.vm_name}"

  #provisioner info:
  communicator         = "winrm"
  winrm_insecure       = true
  winrm_password       = "${var.winrm_password}"
  winrm_use_ssl        = true
  winrm_username       = "${var.winrm_username}"
  winrm_timeout        = "60m"
  #task_timeout         = "20m" // On slow disks the imgcopy operation takes > 1m
  
  #deterministtic port for vnc debugging:
  vnc_port_min = 5998
  vnc_port_max = 5998
}

build {
  sources = ["source.qemu.win11-23h2-x64-enterprise"]

  provisioner "windows-shell" {
    scripts = ["scripts/disablewinupdate.bat"]
  }

  provisioner "powershell" {
    scripts = ["scripts/disable-hibernate.ps1"]
  }

  provisioner "powershell" {
    scripts = ["scripts/install-virtio-drivers.ps1"]
  }

}
