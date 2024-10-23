# FAQ

1.   IS LME 2.0 A FULL REINSTALL OR AN UPDATE?  
 
LME has an upgrade process from 1.4 -> 2.0. the upgrade uninstalls 1.4 and installs 2.0, and will re integrate old dashboards and data into the new 2.0 deployment. This link will eventually work when lme 2.0 is merged: https://github.com/cisagov/LME/blob/main/docs/markdown/maintenance/upgrading.md

2.   IN LIGHT OF VERSION 2.0, WILL OLDER VERSIONS OF LME STOP WORKING?  
 
Older versions will continue to run, but we won’t actively maintain any older versions, and help/assistance will be even more limited.

3.   HOW DO I TRANSITION/MIGRATE FROM OLDER VERSIONS TO LME 2.0 WHILE RETAINING MY LOG HISTORY? 

We will have documentation in place that covers transition from 1.X to 2.0

4.   CAN I TRANSFER MY CUSTOMIZED DASHBOARDS? IF SO, HOW?

Yes, you can import your dashboards on Elastic from Stack Management > Kibana > Saved Objects and click import and select the custom dashboard ndjson file to import it into your Elastic instance.

5.   ARE THERE NEW, UPDATED SYSTEM REQUIREMENTS FOR LME 2.0? 

Requirements are basically the same, but those are minimal and really should be upgraded if the user wants to run 100s of agents

6.   WHERE CAN I RECEIVE FURTHER SUPPORT? 

For support on LME-related issues, users can submit an issue in Github. Users can also create a discussion if the issue is something with their setup rather than a bug in the software

                   
# Other Questions:                       
 
## Basic Troubleshooting
You can find basic troubleshooting steps in the [Troubleshooting Guide](troubleshooting.md).

## Finding your LME version (and the components versions)
When reporting an issue or suggesting improvements, it is important to include the versions of all the components, where possible. This ensures that the issue has not already been fixed!

### Linux Server
* Podman: on the Linux server type ```podman --version```
* Linux: on the Linux server type ```cat /etc/os-release```
* LME: show the contents of ```/opt/lme/config```, please redact private data

## Reporting a bug
To report an issue with LME please use the GitHub 'issues' tab at the top of the (GitHub) page or click [GitHub Issues](https://github.com/cisagov/lme/issues).

## Questions about individual installations
Please visit [GitHub Discussions](https://github.com/cisagov/lme/discussions) to see if your issue has been addressed before.

