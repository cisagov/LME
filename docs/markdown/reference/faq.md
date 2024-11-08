# FAQ

## 1. What Is CISA’s Logging Made Easy (LME)?

LME is a no-cost log management solution for small- to medium-sized organizations with limited resources that would otherwise have little to no functionality to detect attacks. LME offers centralized logging for Linux, macOS, and Windows operating systems, enabling proactive threat detection and enhanced security by allowing organizations to monitor their networks, identify users, and actively analyze Sysmon data to quickly detect potential malicious activity.

## 2. What makes LME unique?

LME stands out as an accessible, open source log management and threat detection solution developed by CISA to support organizations with limited resources. By integrating Elastic and Wazuh in a secure, containerized stack, it provides endpoint security and real-time alerting without the complexity or cost of traditional SIEMs. Designed with customizable dashboards and Secure by Design principles, LME offers a user-friendly, effective solution to enhance visibility and strengthen threat detection.

## 3. What software drives LME?

LME is powered by Elastic Stack (for log management, search, and visualization), Wazuh (for endpoint detection and response), and Podman (for containerization). This open source stack ensures transparency, flexibility and scalability while providing enhanced threat detection and customizable dashboards.

## 4. Which operating systems can use LME?

LME 2.0 supports Windows, Linux, and macOS operating systems. Elastic and Wazuh agents enable compatibility across these platforms, ensuring broad coverage for monitoring and logging. While Wazuh agents also support Solaris, AIX, and HP-UX operating systems, CISA has not tested LME on endpoints running these operating systems.

## 5. Who can use LME?

While intended for small to medium-sized organizations with limited resources, anyone can download and use LME. Reference [LME 2.0 Prerequisite documentation](/docs/markdown/prerequisites.md) for more details on required infrastructure and hardware including CPU, memory, and storage requirements.

## 6. Can LME run in the cloud?

LME supports both on-premises and cloud deployments, allowing organizations to host LME on local or cloud service provider (CSP) infrastructure.

## 7. Does LME 2.0 require a new install or an update to existing installs?

Both new and existing users must complete a full install of LME 2.0.

LME has an upgrade process from v1.4 -> 2.0. The upgrade uninstalls 1.4 and installs 2.0, and will reintegrate old dashboards and data into the new 2.0 deployment. Checkout our [Upgrading docs](/scripts/upgrade/README.md) for more information on upgrading from an older version of LME to LME 2.0.

## 8. How do I download LME?

Detailed installation and download steps can be found on the [Installation section of our ReadMe](https://github.com/cisagov/LME/tree/lme-2-docs?tab=readme-ov-file#installing-lme)

## 9.   In light of LME 2.0, will older versions of LME stop working? 

While CISA recommends upgrading to LME 2.0, users can continue using older versions of LME, however, CISA will not support older versions. 


## 10. How do I transition/migrate from older versions to LME 2.0 while retaining my log history?

For existing LME users, [click here](/scripts/upgrade) for easy instructions on transferring log history from previous versions. LME will automatically reintegrate your log history and data.

## 11.  Can I transfer my customized dashboards? If so, how?

Yes, you can import your dashboards on Elastic from Stack Management > Kibana > Saved Objects and click import and select the custom dashboard ndjson file to import it into your Elastic instance. You'll need to export your old dashboards first. 

## 12. Are there new system requirements for LME 2.0?

Although system requirements are mostly the same for LME 2.0, we do have  hardware and infrastructure recommendations in our [LME 2.0 Prerequisite documentation](/docs/markdown/prerequisites.md)

## 13. Where can I receive further support?

For further support with LME 2.0 users can explore the following options:
•	Report LME issues via the GitHub 'Issues' tab at the top of the page or by clicking GitHub Issues
•	Visit GitHub 'Discussions' to check if your issue has been addressed or start a new thread
•	Directly email CyberSharedServices@cisa.dhs.gov for other questions or comments

## 14. Where Can I Find Additional Resources?

Please visit [CISA’s LME website](https://www.cisa.gov/resources-tools/services/logging-made-easy) for additional resources.
                   
# Other Questions:                       
 
## Basic troubleshooting
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

