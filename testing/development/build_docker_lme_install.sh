#!/usr/bin/env bash
cd testing/configure || exit
sudo ./linux_update_system.sh
sudo ./linux_install_lme.sh -b cbaxley-168-python_tests
. lib/functions.sh
extract_credentials
cd ../tests/ || exit
pip install -r requirements.txt
#pytest api_tests/linux_only/
