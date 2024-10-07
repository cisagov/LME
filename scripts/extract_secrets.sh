#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: source $0 [-p] [-q]"
    echo "  -p    Print the secret values (use with caution)"
    echo "  -q    Quiet mode (suppress all output)"
}

# Default behavior: don't print secrets and don't suppress output
PRINT_SECRETS=false
QUIET_MODE=false

# Parse command line options
while getopts ":pq" opt; do
    case ${opt} in
        p )
            PRINT_SECRETS=true
            ;;
        q )
            QUIET_MODE=true
            ;;
        \? )
            print_usage
            return 1
            ;;
    esac
done

# Function to echo only if not in quiet mode
echo_if_not_quiet() {
    if ! $QUIET_MODE; then
        echo "$@"
    fi
}

# Source the profile to ensure podman is available in the current shell
if [ -f ~/.profile ]; then
    . ~/.profile
else
    echo_if_not_quiet "~/.profile not found. Make sure podman is in your PATH."
    return 1
fi

# Find the full path to podman
PODMAN_PATH=$(which podman)

if [ -z "$PODMAN_PATH" ]; then
    echo_if_not_quiet "podman command not found. Please ensure it's installed and in your PATH."
    return 1
fi

echo_if_not_quiet "Found podman at: $PODMAN_PATH"

# Run the podman secret ls command with sudo and capture the output
output=$(sudo "$PODMAN_PATH" secret ls)

# Check if the command was successful
if [ $? -ne 0 ]; then
    echo_if_not_quiet "Failed to run 'sudo $PODMAN_PATH secret ls'. Check your permissions and podman installation."
    return 1
fi

# Process the output and create a string of export commands
export_commands=""
while IFS= read -r line; do
    if [[ $line != ID* ]]; then  # Skip the header line
        # Parse the line into variables
        read -r id name driver created updated <<< "$line"
        
        # Use the name as-is for the variable name
        var_name=$name
        
        # Get the real password using ansible-vault
        secret_value=$(sudo -i ansible-vault view /etc/lme/vault/$id)
        
        # Add export command to the string
        export_commands+="export $var_name='$secret_value'; "
        
        if $PRINT_SECRETS && ! $QUIET_MODE; then
            echo "Exported $var_name: $secret_value"
        elif ! $QUIET_MODE; then
            echo "Exported $var_name"
        fi
    fi
done <<< "$output"

# Execute the export commands
eval "$export_commands"

if $PRINT_SECRETS && ! $QUIET_MODE; then
    echo "Exported variables with values:"
    env | grep -E "^(wazuh|wazuh_api|kibana_system|elastic)="
elif ! $QUIET_MODE; then
    echo "Exported variables (values hidden):"
    env | grep -E "^(wazuh|wazuh_api|kibana_system|elastic)=" | cut -d= -f1
fi

if ! $QUIET_MODE; then
    echo ""
    echo "To use these variables in your current shell, source this script instead of executing it:"
    echo "source $0        # to export variables without printing values"
    echo "source $0 -p     # to export variables and print values (use with caution)"
    echo "source $0 -q     # to export variables without any output"
fi