#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 [-h] RULE_FILE_NAME"
    echo "RULE_FILE_NAME is the name of the rule you want to test in /opt/lme/config/elastalert2/rules"
}

# Source the profile to ensure podman is available in the current shell
if [ -f ~/.profile ]; then
    . ~/.profile 
else
    echo "~/.profile not found. Make sure podman is in your PATH."
    return 1
fi

# Find the full path to podman
PODMAN_PATH=$(which podman)

if [ -z "$PODMAN_PATH" ]; then
    echo "podman command not found. Please ensure it's installed and in your PATH."
    return 1
fi

echo "Found podman at: $PODMAN_PATH"

# Run the podman secret ls command with sudo and capture the output
output=$(sudo "$PODMAN_PATH" secret ls)

# Check if the command was successful
if [ $? -ne 0 ]; then
    echo "Failed to run 'sudo $PODMAN_PATH secret ls'. Check your permissions and podman installation."
    return 1
fi

#Run rule test
sudo -i $PODMAN_PATH run -it --rm --net lme --env-file=/opt/lme/lme-environment.env -e ES_HOST=lme-elasticsearch -e ES_PORT=9200 -e ES_USERNAME=elastic --secret elastic,type=env,target=ES_PASSWORD \
-v /opt/lme/config/elastalert2/config.yaml:/opt/elastalert/config.yaml -v /opt/lme/config/elastalert2/rules:/opt/elastalert/rules -v /opt/lme/config/elastalert2/misc:/opt/elastalert/misc \
--entrypoint elastalert-test-rule localhost/elastalert2:LME_LATEST /opt/elastalert/rules/$1

