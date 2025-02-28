# Password Encryption:
Ansible-vault is used to enable password encryption, securely storing all LME user and service user passwords at rest
We do submit a hash of the password to Have I Been Pwned to check to see if it is compromised: [READ MORE HERE](https://haveibeenpwned.com/FAQs), but since they're all randomly generated this should be rare.

### Where Are Passwords Stored?:
```bash
# Define user-specific paths
USER_VAULT_DIR="/etc/lme/vault"
PASSWORD_FILE="/etc/lme/pass.sh"
```

### Grabbing Passwords: 
To view the appropriate service user password run the following commands:
```
#script:
$CLONE_DIRECTORY/scripts/extract_secrets.sh -p #to print

#add them as variables to your current shell
source $CLONE_DIRECTORY/scripts/extract_secrets.sh #without printing values
source $CLONE_DIRECTORY/scripts/extract_secrets.sh -q #with no output
```

### Manually Setting Up Passwords and Accessing Passwords **Unsupported**:
**These steps are not fully supported by CISA and are left if others would like to support this in their environment**

Run the password_management.sh script:
```bash
lme-user@ubuntu:~/LME-TEST$ sudo -i ${PWD}/scripts/password_management.sh -h
-i: Initialize all password environment variables and settings
-s: set_user: Set user password
-p: Manage Podman secret
-l: List Podman secrets
-h: print this list
```

A cli one liner to grab passwords (this also demonstrates how we're using Ansible-vault in extract_secrets.sh):
```bash
#where wazuh_api is the service user whose password you want:
USER_NAME=wazuh_api
sudo -i ansible-vault view /etc/lme/vault/$(sudo -i podman secret ls | grep $USER_NAME | awk '{print $1}')
```




