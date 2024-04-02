# FAQ

## Basic Troubleshooting
Troubleshooting steps are in the [Troubleshooting Guide](troubleshooting.md).

## Finding your LME version (and the components versions)
When reporting an issue or suggesting improvements, it is important to include the versions of all the components, when possible, to ensure that the issue has not already been fixed.

### Windows Server
* Operating System: Press "Windows Key"+R and type ```winver```
* WEC Config: Open EventViewer > Subscriptions > "LME" > Description should contain version number
* Winlogbeat Config: At the top of the file C:\Program Files\lme\winlogbeat.yml there should be a version number.
* Winlogbeat.exe version: Press "Windows Key"+R and type ```"C:\Program Files\lme\winlogbeat.exe" version```
* Sysmon config: From either the top of the file or look at the status dashboard
* Sysmon executable: Either run sysmon.exe or look at the status dashboard



### Linux Server
* Docker: on the Linux server type ```docker --version```
* Linux: on the Linux server type ```cat /etc/os-release```
* Logstash config: on the Linux server type ```sudo docker config inspect logstash.conf --pretty```




## Reporting a bug
To report an issue with LME please use the GitHub 'issues' tab at the top of the (GitHub) page or click [GitHub Issues](https://github.com/cisagov/lme/issues).

## Questions about individual installations
Please visit [GitHub Discussions](https://github.com/cisagov/lme/discussions) to see if your issue has been addressed before.
