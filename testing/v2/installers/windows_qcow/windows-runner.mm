clear vm config
shell sleep 10 
vm config memory 2048
vm config vcpus 2
vm config disk /opt/win11_ccc.qcow2 
vm config snapshot true
vm config net 100
vm launch kvm windows-runner
vm start windows-runner
