# Directory Layout

This is an experimental directory, not all scripts are finished.


## Directories
- group_vars/
    - used for ansible
- orc/
    - in progress python package to help generate experiments more complex than just two nodes. 
    - not used right now, may be revisited
- playbooks/
    - helpful ansible playbooks for configuring VMs
- roles/
    - more ludus playbooks, not used right now
- templates/
    - packer templates adapted from public ludus templates

## Top level files
- dnsmasq.mm
    - minimega scripts that configures networking. Contents are present in README during set up section
- generate.py
    - generates ansible and ludus configurations. Experimental, not tested
- inventory.ini
    - ansible inventory file
