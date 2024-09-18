#!/bin/bash
#set -e  # Exit on any error
set +x  # Disable bash debugging output

# Define user-specific paths
USER_CONFIG_DIR="/root/.config/containers"
USER_SECRETS_CONF="$USER_CONFIG_DIR/containers.conf"
USER_VAULT_DIR="/opt/lme/vault"
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
        read -s -p "$prompt" password
        echo
        read -s -p "Confirm password: " password_confirm
        echo
        [ "$password" = "$password_confirm" ] && break
        echo "Passwords do not match. Please try again."
    done
    export READ_PASSWORD="$password"
}

#https://stackoverflow.com/questions/929368/how-to-test-an-internet-connection-with-bash#26820300
check_connect() {
website=$1

RES=$(wget -q --spider $1)

if [ $? -eq 0 ]; then
    #echo "$1 Online"
    echo -n ""
else
    echo "$1 Offline"
    echo "Are you connected to the internet? we check all passwords against HIBP to ensure NIST compliance"
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
lookup = "ansible-vault view $USER_VAULT_DIR/\$SECRET_ID"
store = "cat > $USER_VAULT_DIR/\$SECRET_ID && chmod 700 $USER_VAULT_DIR/\$SECRET_ID && ansible-vault encrypt $USER_VAULT_DIR/\$SECRET_ID"
delete = "rm $USER_VAULT_DIR/\$SECRET_ID"
EOF
chmod 600 "$USER_SECRETS_CONF"
}

# Function to set and encrypt user password
set_user_password() {
    local user="$1"
    local password=$(read_password "Enter password for $user: ")
    
    mkdir -p "$USER_VAULT_DIR"
    chmod 700 "$USER_VAULT_DIR"
    
    # Write password to file with secure permissions
    echo "$password" > "$USER_VAULT_DIR/$user"
    chmod 700 "$USER_VAULT_DIR/$user"
    
    ansible-vault encrypt "$USER_VAULT_DIR/$user"
    
    echo "Password for $user has been set and encrypted."
    echo "$password"
}

# Function to manage Podman secrets
manage_podman_secret() {
    local action="$1"
    local secret_name="$2"
    local secret_value="$3"

    case "$action" in
        create|update)
            # Use process substitution to avoid writing to a file or showing the secret in ps output
            podman secret create --driver shell --replace "$secret_name" <(echo "$secret_value")
            ;;
        delete)
            podman secret rm "$secret_name"
            ;;
        list)
            podman secret ls
            ;;
        *)
            echo "Invalid action. Use 'create', 'update', 'delete', or 'list'."
            return 1
            ;;
    esac
}

# Main menu
man_page(){
  echo "-i: Initialize all password environment variables and settings"
  echo "-s: set_user: Set user password"
  echo "-p: Manage Podman secret"
  echo "-l: List Podman secrets"
  echo "-h: print this list"
}

while getopts "isplc:h" opt; do
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
        #TODO: test this
        read -p "Enter username: " username
        password=$(set_user_password "$username")
        # Use command substitution to avoid echoing the password
        manage_podman_secret create "$username" "$(echo "$password")"
        ;;
    p)
        if [ -z "secret_name" ];then
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
