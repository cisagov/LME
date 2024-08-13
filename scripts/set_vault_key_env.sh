#!/bin/bash
read -s -p "ANSIBLE_VAULT_PASSWORD:" LME_ANSIBLE_VAULT_PASS
export LME_ANSIBLE_VAULT_PASS=$LME_ANSIBLE_VAULT_PASS

#TODO: add checks for these filepaths existing
#set password file ansible-vault variable
export ANSIBLE_VAULT_PASSWORD_FILE=/opt/lme/config/vault-pass.sh
