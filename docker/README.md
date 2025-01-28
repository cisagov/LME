# LME docker setup
All of the commands in this guide should be run from the docker directory of the repository `LME/docker`.

## Prerequisites

- Docker
- Docker Compose

Note: If you are running linux on a hypervisor, or virtual machine, you may need to add the following to the GRUB_CMDLINE_LINUX line in /etc/default/grub:
```bash
GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0 cgroup_enable=memory swapaccount=1"
```

Then run the following command to update grub and reboot:

```bash
sudo update-grub
```

## Build and run the docker container
This will install LME into a docker container. It will take a while to complete.
```bash
docker compose build
docker compose up -e 
```

## Check the logs of the LME setup in docker

It will take some time for the LME setup to finish. It can hang for 15 minutes or so on any of the steps, so be patient.

Using docker compose and journalctl, you can watch the logs of the LME setup in docker:
```bash
docker compose exec lme journalctl -u lme-setup -f -o cat --no-hostname
```
## Checking the status of the LME setup
(optional) In order to check the status (but not the logs) of the LME setup in docker, you can use the following commands:

#### For Linux:
```bash
./check-lme-setup.sh
```

#### For Windows:
First, you'll need to run PowerShell as Administrator. Right-click on PowerShell and select "Run as Administrator"

Then, you can change the execution policy by running one of these commands:

Note: "RemoteSigned" allows you to run local scripts while still requiring downloaded scripts to be signed by a trusted publisher. This is generally considered a good balance between security and usability.

```powershell
# Option 1 - Change policy for the current user only (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Option 2 - Change policy system-wide (requires admin rights)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

After running either command, type "Y" to confirm the change

Now you should be able to run your script normally:

```powershell
.\check-lme-setup.ps1
```

