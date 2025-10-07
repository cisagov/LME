# LME Docker Setup
Download and unzip the latest release of LME from the [releases page](https://github.com/cisagov/lme/releases) into your home directory.

This guide is for setting up the LME container using Docker. It is NOT persistent, which means you will need to run, and rebuild, the container again after stopping it.
It is for testing purposes only, so you can easily install and examine the parts of the LME stack.

All commands in this guide should be run from the `LME/docker` directory of the repository.
You can choose either the 22.04 or 24.04 directories to build the container.


## Prerequisites

- A current version of Docker which should include Docker compose (there is an installer script for ubuntu in the `docker` directory)
- At least 20GB of RAM 
- 100GB of disk space preferred

Note: We have installed Docker desktop on Windows and Linux and have been able to build and run the container.

### Special instructions for Windows running Linux
If running Linux on a hypervisor or virtual machine, you may need to modify the GRUB configuration in your VM (only if you have problems):

1. Add the following to the `GRUB_CMDLINE_LINUX` line in `/etc/default/grub`:
```bash
GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0 cgroup_enable=memory swapaccount=1"
```

2. Update GRUB and reboot:
```bash
sudo update-grub
sudo reboot
```

## Building and Running LME

1. Cd to the version you want to run (eg `cd LME/docker/22.04`) and build the container (this may take several minutes):
```bash
docker compose build
```
2. Copy the  environment_example.sh file to environment.sh and set the IP address of the host machine that you will access the LME UI from.

Set this variable to the ip of the host machine. 
```bash
export HOST_IP=192.168.50.205
```
3. Start the container:
```bash
docker compose up -d
```

## Monitoring Setup Progress

The initial LME setup can take 15-30 minutes to complete. Here are ways to monitor the progress:

### View Setup Logs
Watch the detailed setup logs and wait for it to report that the setup is complete:
```bash
docker compose exec lme journalctl -u lme-setup -f -o cat --no-hostname
```
When the setup is complete, you will see something like this:
```bash
Setup completed at Tue Feb 11 12:42:30 PM UTC 2025
First-time initialization complete.
Finished LME Setup Service.
```

### Check Setup Status
This will check the status of the setup and report if it is complete, but it doesn't report the progress.
Check the current setup status:

#### Linux:
```bash
./check-lme-setup.sh
```

#### Windows PowerShell:
1. Run PowerShell as Administrator
2. Enable script execution (one-time setup):
```powershell
# For current user only (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
3. Run the status check:
```powershell
.\check-lme-setup.ps1
```

## Accessing the Container

### List Running Containers
These must be run in the directory of the version you are using.
View all running containers:
```bash
docker compose ps
```

### Access Container Shell
Enter the running container:
```bash
docker compose exec lme bash
```
This will give you a root shell into the container and you can follow the instructions on the main readme about how 
to check containers within the container. In the [main readme](https://github.com/cisagov/lme?tab=readme-ov-file#table-of-contents)  
locate the "Post installation steps" section and the sections that follow, to manage and access the system.

### Getting passwords for the users
The passwords for the users are accessed by running the following command:
```bash
docker compose exec lme bash -c "/root/LME/scripts/extract_secrets.sh -p"
```
The user and password for the LME UI are:
```bash
elastic=password_printed_in_the_last_command
# user: elastic
# password: password_printed_in_the_last_command
```

### Access the LME UI
The LME UI is available at https://localhost

### Stop the Container
When you're done:
```bash
docker compose down
```

## Troubleshooting

- If the container fails to start, check the logs:
```bash
docker compose logs lme
```

- If you need to rebuild from scratch:
```bash
docker compose down -v 
docker compose build --no-cache
docker compose up -d
```

