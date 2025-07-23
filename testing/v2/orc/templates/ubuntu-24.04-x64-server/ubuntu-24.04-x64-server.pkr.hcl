variable "iso_checksum" {
  type    = string
  default = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
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
  default = "200G"
}

variable "vm_memory" {
  type    = string
  default = "8192"
}

variable "vm_name" {
  type    = string
  default = "ubuntu-24.04-x64-server-template"
}

variable "ssh_password" {
  type    = string
  default = "password"
}

variable "ssh_username" {
  type    = string
  default = "localuser"
}

variable "proxmox_storage_pool" {
  type = string
}
variable "proxmox_storage_format" {
  type = string
  default = "qcow2"
}
variable "ansible_home" {
  type = string
}



source "qemu" "ubuntu2404-server" {
  boot_command = [
    "e<down><down><down><end><wait>",
    " autoinstall<wait>",
    " ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'",
    "<wait10>",
    "<F10>"
  ]
  boot_key_interval      = "100ms"
  boot_keygroup_interval = "2s"
  http_directory         = "./http"

  communicator    = "ssh"
  cores           = "${var.vm_cpu_cores}"
  cpu_model = "host"
  accelerator = "kvm"
  headless = "true"

	#booting vm:
  disk_size        = "${var.vm_disk_size}"
  format            = "${var.proxmox_storage_format}"
  cpus             = "${var.vm_cpu_cores}"
  memory           = "${var.vm_memory}"

  #disk sotrage:
  output_directory = "${var.proxmox_storage_pool}/${var.vm_name}"
  vm_name          = "${var.vm_name}"
  
  #iso_checksum             = "${var.iso_checksum}"
  iso_url                  = "${var.iso_url}"

  #deterministtic port for vnc debugging:
  iso_checksum             = "none"
  vnc_port_min = 5998
  vnc_port_max = 5998

  #login:
  ssh_password         = "${var.ssh_password}"
  ssh_username         = "${var.ssh_username}"
  ssh_timeout     = "30m"
}

build {
  sources = ["source.qemu.ubuntu2404-server"]

  provisioner "ansible" {
    playbook_file = "ansible/reset-machine-id.yml"
    use_proxy     = false
    user = "${var.ssh_username}"
    extra_arguments = ["--extra-vars", "{ansible_python_interpreter: /usr/bin/python3, ansible_password: ${var.ssh_password}, ansible_sudo_pass: ${var.ssh_password}}"]
    ansible_env_vars = ["ANSIBLE_HOME=${var.ansible_home}", "ANSIBLE_LOCAL_TEMP=${var.ansible_home}/tmp", "ANSIBLE_PERSISTENT_CONTROL_PATH_DIR=${var.ansible_home}/pc", "ANSIBLE_SSH_CONTROL_PATH_DIR=${var.ansible_home}/cp"]
    skip_version_check = true
  }

  provisioner "ansible" {
    playbook_file = "ansible/reset-ssh-host-keys.yml"
    use_proxy     = false
    user = "${var.ssh_username}"
    extra_arguments = ["--extra-vars", "{ansible_python_interpreter: /usr/bin/python3, ansible_password: ${var.ssh_password}, ansible_sudo_pass: ${var.ssh_password}}"]
    ansible_env_vars = ["ANSIBLE_HOME=${var.ansible_home}", "ANSIBLE_LOCAL_TEMP=${var.ansible_home}/tmp", "ANSIBLE_PERSISTENT_CONTROL_PATH_DIR=${var.ansible_home}/pc", "ANSIBLE_SSH_CONTROL_PATH_DIR=${var.ansible_home}/cp"]
    skip_version_check = true
  }
  
  provisioner "ansible" {
    playbook_file = "ansible/ensure-utf-8-locale.yml"
    use_proxy     = false
    user = "${var.ssh_username}"
    extra_arguments = ["--extra-vars", "{ansible_python_interpreter: /usr/bin/python3, ansible_password: ${var.ssh_password}, ansible_sudo_pass: ${var.ssh_password}}"]
    ansible_env_vars = ["ANSIBLE_HOME=${var.ansible_home}", "ANSIBLE_LOCAL_TEMP=${var.ansible_home}/tmp", "ANSIBLE_PERSISTENT_CONTROL_PATH_DIR=${var.ansible_home}/pc", "ANSIBLE_SSH_CONTROL_PATH_DIR=${var.ansible_home}/cp"]
    skip_version_check = true
  }
}
