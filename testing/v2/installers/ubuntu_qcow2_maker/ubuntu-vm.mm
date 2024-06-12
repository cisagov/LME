clear vm config
vm config memory 2048
vm config vcpus 2
vm config disk /home/vbox/src/LME/testing/v2/installers/ubuntu_qcow2_maker/ubuntu-vm.qcow2
vm config qemu-append -drive file=/home/vbox/src/LME/testing/v2/installers/ubuntu_qcow2_maker/seed.img,media=cdrom,index0,readonly
vm config snapshot false
vm launch kvm ubuntu-vm
