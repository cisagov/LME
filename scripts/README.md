# Upgrading from 1x to 2x
1. Checkout the latest version of the LME repository to your home directory
    ```bash
    cd ~
    git clone https://github.com/cisagov/LME.git
    ```
1. Export indices:

    Note: *This may take some time witout feedback. Make sure it finishes successfully*

    A successful completion looks like this:
    ```bash
    Data and mappings export completed. Backup stored in: /lme_backup
    Files created:
    - /lme_backup/winlogbeat_data.json.gz
    - /lme_backup/winlogbeat_mappings.json.gz
    ```
    Run this command to export the indices: 
    ```bash
    cd ~/LME/scripts/upgrade
    sudo ./export_1x.sh
    ```
1. Either export the dashboards or use the existing ones
    - If you don't have custom dashboards, you can use the path to the existing ones in the following steps
        ```bash
        /opt/lme/Chapter 4 Files/dashboards/
        ```
    - If you have custom dashboards, you will need to export them and use that path:
        ```bash
        # Export all of the dashboards, it is the last option
        cd ~/LME/scripts/upgrade/
        pip install -r requirements.txt
        export_dashboards.py -u elastic -p yourpassword
        ```
        - Your path to use for the importer will be:
        ```bash
        /yourhomedirectory/LME/scripts/upgrade/exported/
        ```
1. Uninstall old LME version 
    ```bash
    sudo su
    cd "/opt/lme/Chapter 3 Files/"
    ./deploy.sh uninstall

    # Go back to your user
    exit 

    # If you are using docker for more than lme (You want to keep docker)
    sudo docker volume rm lme_esdata
    sudo docker volume rm lme_logstashdata

    # If you are only using docker for lme 
    # Remove existing volumes
    cd ~/LME/scripts/upgrade
    sudo su # Become root in the right directory
    ./remove_volumes.sh
    # Uninstall Docker  
    ./uninstall_docker.sh

    # Rename the directory to make room for the new install
    mv /opt/lme /opt/lme-old
    exit # Go back to regular user
    ```
1. Install LME version 2x
    ```bash
    #***** Make sure you are running as normal user *****#
    sudo apt-get update && sudo apt-get -y install ansible

    # Copy the environment file 
    cp ~/LME/config/example.env ~/LME/config/lme-environment.env

    # Edit the lme-environment.env and change all the passwords
    # vim ~/LME/config/lme-environment.env 

    # Change to the script directory
    cd ~/LME/scripts/

    ansible-playbook install_lme_local.yml

    # Load podman into your enviornment
    . ~/.bashrc 

    # Have the full paths of the winlogbeat files that you exported earlier ready
    ./upgrade/import_1x.sh

    # Use the path from above dashboard update or original dashboards
    sudo ./upgrade/import_dashboards.sh -d /opt/lme-old/Chapter\ 4\ Files/dashboards/
    ```