clear vm config
shell sleep 10 
vm config memory 2048
vm config vcpus 2
vm config disk /home/cbaxley/src/LME/testing/v2/installers/ubuntu_qcow_maker/jammy-server-cloudimg-amd64.img
vm config snapshot true
vm config net 100
vm launch kvm ubuntu-runner
vm start ubuntu-runner
