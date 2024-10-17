# FAQ

## Basic Troubleshooting
You can find basic troubleshooting steps in the [Troubleshooting Guide](troubleshooting.md).

## Finding your LME version (and the components versions)
When reporting an issue or suggesting improvements, it is important to include the versions of all the components, where possible. This ensures that the issue has not already been fixed!

### Windows Server
* Operating System: Press "Windows Key"+R and type ```winver```
* WEC Config: Open EventViewer > Subscriptions > "LME" > Description should contain version number
* Winlogbeat Config: At the top of the file C:\Program Files\lme\winlogbeat.yml there should be a version number.
* Winlogbeat.exe version: Press "Windows Key"+R and type ```"C:\Program Files\lme\winlogbeat.exe" version```
* Sysmon config: From either the top of the file or look at the status dashboard
* Sysmon executable: Either run sysmon.exe or look at the status dashboard


### Linux Server
* Podman: on the Linux server type ```podman --version```
* Linux: on the Linux server type ```cat /etc/os-release```
* LME: show the contents of ```/opt/lme/config```, please redact private data


## Reporting a bug
To report an issue with LME please use the GitHub 'issues' tab at the top of the (GitHub) page or click [GitHub Issues](https://github.com/cisagov/lme/issues).

## Questions about individual installations
Please visit [GitHub Discussions](https://github.com/cisagov/lme/discussions) to see if your issue has been addressed before.
