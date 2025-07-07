#!/bin/bash
#set -e  # Exit on any error
set +x  # Disable bash debugging output

# Define user-specific paths
USER_CONFIG_DIR="/root/.config/containers"
USER_SECRETS_CONF="$USER_CONFIG_DIR/containers.conf"
USER_VAULT_DIR="/etc/lme/vault"
CONFIG_DIR="/etc/lme"
PASSWORD_FILE="$CONFIG_DIR/pass.sh"

#NIST Guidelines (NIST Special Publication 800-63B):
check_password() {
    local password="$1"
    local min_length=12

    # Check password length
    if [ ${#password} -lt $min_length ]; then
        echo "Input is too short. It should be at least $min_length characters long."
        return 1
    fi

    # Skip HIBP check if in offline mode
    if [ "$OFFLINE_MODE" = "true" ]; then
        echo "Offline mode enabled - skipping HIBP password breach check."
        echo "Input meets the complexity requirements. Ensure you are using a secure password."
        return 0
    fi

    # Generate SHA-1 hash of the password
    hash=$(echo -n "$password" | openssl sha1 | awk '{print $2}')
    prefix="${hash:0:5}"
    suffix="${hash:5}"

    # Check against HIBP API
    response=$(curl -s "https://api.pwnedpasswords.com/range/$prefix")

    if echo "$response" | grep -qi "$suffix"; then
        echo "This input has been found in known data breaches. Please choose a different one."
        return 1
    fi

    # If we've made it here, the input meets the requirements
    echo "Input meets the complexity requirements and hasn't been found in known data breaches."
    return 0
}

# Function to securely read password
read_password() {
    local prompt="$1"
    local password
    while true; do
        # Read password without newline
        read -s -p "$prompt" password
        printf '\n' >&2  # Move cursor to next line
        read -s -p "Confirm password: " password_confirm
        printf '\n' >&2  # Move cursor to next line
        [ "$password" = "$password_confirm" ] && break
        echo "Passwords do not match. Please try again." >&2
    done
    # Export password without any newlines
    export READ_PASSWORD="$password"
}

#https://stackoverflow.com/questions/929368/how-to-test-an-internet-connection-with-bash#26820300
check_connect() {
website=$1

# Skip connectivity check if in offline mode
if [ "$OFFLINE_MODE" = "true" ]; then
    echo "Offline mode enabled - skipping connectivity check"
    return 0
fi

RES=$(wget -q --spider $1)

if [ $? -eq 0 ]; then
    #echo "$1 Online"
    echo -n ""
else
    echo "$1 Offline"
    echo "Are you connected to the internet? we check all passwords against HIBP to ensure NIST compliance"
    echo "Use OFFLINE_MODE=true to skip internet checks"
    exit -1
fi
}

set_password_file(){

while [ -z "$ANSIBLE_VAULT_PASSWORD"  ] || ! check_password "$ANSIBLE_VAULT_PASSWORD"; do
  read_password "Enter ANSIBLE_VAULT_PASSWORD: "
  export ANSIBLE_VAULT_PASSWORD=$READ_PASSWORD
done

#setup global config dir
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# Ensure config directory exists and is secure
mkdir -p "$USER_CONFIG_DIR"
chmod 700 "$USER_CONFIG_DIR"

# Ensure config directory exists and is secure
mkdir -p $USER_VAULT_DIR
chmod 700 "$USER_CONFIG_DIR"

# Create vault-pass.sh with secure permissions
cat > "$PASSWORD_FILE" << EOF
#!/bin/bash
echo "$ANSIBLE_VAULT_PASSWORD"
EOF
chmod 700 "$PASSWORD_FILE"

# Set Ansible vault password file variable
if ! grep -q "ANSIBLE_VAULT_PASSWORD_FILE" /root/.profile; then
    echo "export ANSIBLE_VAULT_PASSWORD_FILE=\"$PASSWORD_FILE\"" >> /root/.profile
fi

# Clear sensitive environment variables
unset ANSIBLE_VAULT_PASSWORD
}

set_podman_config(){
echo "setting up $USER_SECRETS_CONF"
# Podman secrets configuration
mkdir -p "$(dirname "$USER_SECRETS_CONF")"
cat > "$USER_SECRETS_CONF" << EOF
[secrets]
driver = "shell"

[secrets.opts]
list = "ls $USER_VAULT_DIR"
lookup = "ansible-vault view $USER_VAULT_DIR/\$SECRET_ID | tr -d '\n'"
store = "cat > $USER_VAULT_DIR/\$SECRET_ID && chmod 700 $USER_VAULT_DIR/\$SECRET_ID && ansible-vault encrypt $USER_VAULT_DIR/\$SECRET_ID"
delete = "rm $USER_VAULT_DIR/\$SECRET_ID"
EOF
chmod 600 "$USER_SECRETS_CONF"
}

# Function to reset Wazuh password using expect script
reset_wazuh_password() {
    local username="$1"
    local password="$2"
    
    # Only proceed if this is a Wazuh-related user
    if [ "$username" = "wazuh" ] || [ "$username" = "wazuh_api" ]; then
        echo "Resetting password in Wazuh container. This may take a few moments..."
        
        # Execute expect script to change the password
        ./reset_wazuh_password.exp "$username" "$password"
        
        # Update both Podman secrets since both passwords are changed
        manage_podman_secret create "wazuh" "$password"
        manage_podman_secret create "wazuh_api" "$password"
        
        # Confirm completion
        echo "Wazuh password reset completed."
    fi
}

# Function to set and encrypt user password
set_user_password() {
    local user="$1"
    local password
    
    # Read password without command substitution
    read_password "Enter password for $user: "
    password="$READ_PASSWORD"
    
    # Ensure vault directory exists and has correct permissions
    mkdir -p "$USER_VAULT_DIR"
    chmod 700 "$USER_VAULT_DIR"
    
    # Write password to file with secure permissions
    printf '%s' "$password" > "$USER_VAULT_DIR/$user"
    chmod 700 "$USER_VAULT_DIR/$user"
    
    # Encrypt the password file
    ansible-vault encrypt "$USER_VAULT_DIR/$user"
    
    # Send success message to stderr instead of stdout
    echo "Password for $user has been set and encrypted." >&2
    
    # Return just the password to stdout without newline
    printf '%s' "$password"
}

# Function to manage Podman secrets
manage_podman_secret() {
    local action="$1"
    local secret_name="$2"
    local secret_value="$3"

    case "$action" in
        create|update)
            # Debug output
            echo "Setting secret $secret_name with length ${#secret_value}" >&2
            # Create a temporary file for the secret
            local temp_file=$(mktemp)
            printf '%s' "$secret_value" > "$temp_file"
            # Use the temporary file for the secret
            podman secret create --driver shell --replace "$secret_name" "$temp_file"
            rm -f "$temp_file"
            ;;
        delete)
            podman secret rm "$secret_name"
            ;;
        list)
            podman secret ls
            ;;
        *)
            echo "Invalid action. Use 'create', 'update', 'delete', or 'list'." >&2
            return 1
            ;;
    esac
}

# Function to ensure expect is installed
ensure_expect_installed() {
    if ! command -v expect >/dev/null 2>&1; then
        echo "Installing expect..." >&2
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y expect
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y expect
        elif command -v yum >/dev/null 2>&1; then
            yum install -y expect
        else
            echo "Could not install expect. Please install it manually." >&2
            exit 1
        fi
    fi
}

# Function to reset elasticsearch password using expect
reset_elasticsearch_password() {
    local username="$1"
    local password="$2"
    
    # Ensure expect is installed
    ensure_expect_installed
    
    # Inform user about the process
    echo "Resetting password in Elasticsearch container. This may take a few moments..."
    
    # Run expect script with password as argument
    ./reset_elastic_password.exp "$username" "$password"
    
    # Confirm completion
    echo "Password reset completed successfully."
}

# Main menu
man_page(){
  echo "-i: Initialize all password environment variables and settings"
  echo "-s [username]: Set user password (username is optional)"
  echo "-p: Manage Podman secret"
  echo "-l: List Podman secrets"
  echo "-h: print this list"
}

# Show help menu if no arguments provided
if [ $# -eq 0 ]; then
    man_page
    exit 0
fi

while getopts "isp:lch" opt; do
  case "$opt" in 
    i)
        #check connection
        check_connect "https://api.pwnedpasswords.com/range/AAAAA"

        #check if I'm sudo:
        if [[ "$EUID" -ne 0 ]]; then
              echo "rerun with sudo"
              exit -1
        fi

        #set passwords
        echo "Set password"
        set_password_file
        set_podman_config
        ;;
    s)
        if [ -n "$OPTARG" ]; then
            username="$OPTARG"
        else
            read -p "Enter username: " username
        fi
        password=$(set_user_password "$username")
        # Use command substitution to avoid echoing the password
        manage_podman_secret create "$username" "$(echo "$password")"
        # If this is the elastic user or kibana_system user, also reset the elasticsearch password
        if [ "$username" = "elastic" ] || [ "$username" = "kibana_system" ]; then
            reset_elasticsearch_password "$username" "$password"
        fi

        # If this is a Wazuh user, also reset the Wazuh password
        if [ "$username" = "wazuh" ] || [ "$username" = "wazuh_api" ]; then
            reset_wazuh_password "$username" "$password"
        fi
        ;;
    p)
        if [ -n "$OPTARG" ]; then
            secret_name="$OPTARG"
        else
            read -p "Enter secret name: " secret_name
        fi
        if [ -z "action" ];then
          read -p "Enter action (create/update/delete): " action
        fi
        if [ "$action" != "delete" ]; then
            # Use command substitution to avoid echoing the password
            read_password "Enter Secret Value"
            manage_podman_secret "$action" "$secret_name" "$READ_PASSWORD"
        else
            manage_podman_secret delete "$secret_name"
        fi
        ;;
    l)
        manage_podman_secret list
        ;;
    c)
        check_password $OPTARG
        ;;
    h)
        man_page
        ;;
    *)
        echo "Invalid option. Please try again."
        man_page
        ;;
esac
done
