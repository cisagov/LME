# LME docker setup
All of the commands in this guide should be run from the docker directory of the repository.

## Build and run the docker container
```bash
docker compose build
docker compose up -d
```

## Check the status of the LME setup in docker
In order to check the status of the LME setup in docker, you can use the following commands:

For Linux:
```bash
./check-lme-setup.sh
```

For Windows:
First, you'll need to run PowerShell as Administrator. Right-click on PowerShell and select "Run as Administrator"

Then, you can change the execution policy by running one of these commands:

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

"RemoteSigned" allows you to run local scripts while still requiring downloaded scripts to be signed by a trusted publisher. This is generally considered a good balance between security and usability.
