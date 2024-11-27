#!/usr/bin/env bash

# Run from anywhere
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "$SCRIPT_DIR/.env"

# rm -rf "$SCRIPT_DIR/.env"

"$SCRIPT_DIR/install_azure.sh"

. "$SCRIPT_DIR/get_storage_key.sh"  

"$SCRIPT_DIR/download_blob_file.sh"

"$SCRIPT_DIR/start_networking.sh"

/opt/minimega/bin/minimega -e "read /home/lme-user/windows_qcow/windows-runner.mm"

"$SCRIPT_DIR/wait_for_cc.sh" windows-runner

"$SCRIPT_DIR/set_dns.sh"  

"$SCRIPT_DIR/setup_ssh.sh"

"$SCRIPT_DIR/start_ssh_service.sh"

"$SCRIPT_DIR/setup_rdp.sh"

