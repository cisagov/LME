# LME Docker Setup
All commands in this guide should be run from the `LME/docker` directory of the repository.
At this point you can choose 22.04 or 24.04 directories to build the container.

## Prerequisites

- Docker 
- Docker Compose
- At least 20GB of RAM 
- 100GB of disk space preferred

### Special Windows/Linux VM Configuration
If running Linux on a hypervisor or virtual machine, you may need to modify the GRUB configuration in your VM:

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

1. Build the container (this may take several minutes):
```bash
docker compose build
```

2. Start the container:
```bash
docker compose up -d
```

## Monitoring Setup Progress

The initial LME setup can take 15-30 minutes to complete. Here are ways to monitor the progress:

### View Setup Logs
Watch the detailed setup logs:
```bash
docker compose exec lme journalctl -u lme-setup -f -o cat --no-hostname
```

### Check Setup Status
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
View all running containers:
```bash
docker ps
```

### Access Container Shell
Enter the running container:
```bash
docker compose exec lme bash
```

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
docker compose down
docker compose build --no-cache
docker compose up -d
```

