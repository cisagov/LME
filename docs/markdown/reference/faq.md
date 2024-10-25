# FAQ

**1. What Is CISA’S Logging Made Easy (LME)?**

LME is a no-cost log management solution for small- to medium-sized organizations with limited resources that would otherwise have little to no functionality to detect attacks. LME offers centralized logging for Linux, macOS, and Windows operating systems, enabling proactive threat detection and enhanced security by allowing organizations to monitor their networks, identify users, and actively analyze Sysmon data to quickly detect potential malicious activity.

**2. What Makes LME Unique?**

LME performs seamless log management, prioritizing transparency, security and collaboration for unparalleled value. What makes LME so unique is its customizable dashboards that display system logs in real-time.

**3. How to Download LME?**

No sign-up or lengthy onboarding is required. Simply visit CISA’s LME GitHub page for step-by-step instructions on how to download and install. GitHub facilitates open source software development by providing a collaborative platform for hosting, sharing, and managing code repositories, enabling version control, community contributions and issue tracking.

**4. What's In It For Me?**

LME simplifies log management with easy implementation, centralized monitoring and a user-friendly interface. By using LME, users gain real-time threat visibility, enabling proactive detection and response to security events. LME’s commitment to transparency and community collaboration builds trust, reflected in positive reviews. Choosing LME means access to a robust, accessible, and collaborative log management solution aligned with organizational goals for a secure digital future.

**5. What Software Drives LME?**

LME is powered by Elastic Stack (for log management, search, and visualization), Wazuh (for endpoint detection and response), and Podman (for containerization). This open source stack ensures transparency, flexibility and scalability while providing enhanced threat detection and customizable dashboards.

**6. Which Operating Systems Can Use LME?**

LME 2.0 supports Windows, Linux, and macOS operating systems. Elastic and Wazuh agents enable compatibility across these platforms, ensuring broad coverage for monitoring and logging. While Wazuh agents also support Solaris, AIX, and HP-UX operating systems, CISA has not tested LME on endpoints running these operating systems.

**7. Who Can Use LME?**

While intended for small to medium-sized organizations with limited resources, anyone can download LME. Reference (LME 2.0 Prerequisite documentation) for more details on required infrastructure and hardware including CPU, memory, and storage requirements.

**8. Can LME Run In The Cloud?**

LME supports both on-premises and cloud deployments, allowing organizations to host LME on local or cloud service provider (CSP) infrastructure.

**9. Does LME 2.0 Require a Full Reinstall or an Update?**

Both new and existing users must complete a full install of LME 2.0 on LME’s GitHub page where users will also find installation instructions.

LME has an upgrade process from 1.4 -> 2.0. the upgrade uninstalls 1.4 and installs 2.0, and will re integrate old dashboards and data into the new 2.0 deployment. This link will eventually work when lme 2.0 is merged: https://github.com/cisagov/LME/blob/main/docs/markdown/maintenance/upgrading.md

**10.   In Light of Version 2.0, Will Older Versions of LME Stop Working?** 

While CISA recommends upgrading to LME 2.0, users can continue using older versions of LME, however, CISA will not support older versions. 


**11. How Do I Transition/Migrate From Older Versions to LME 2.0 While Retaining My Log History?**

For existing LME users, click here for easy instructions on transferring log history from previous versions. LME will automatically reintegrate your log history and data.

**12.  Can I Transfer My Customized Dashboards? If So, How?**

Yes, you can import your dashboards on Elastic from Stack Management > Kibana > Saved Objects and click import and select the custom dashboard ndjson file to import it into your Elastic instance.

**13. Are there New System Requirements for LME 2.0?**

LME 2.0 system requirements remain mostly unchanged; users can find detailed documentation on the LME GitHub page. Unsure about meeting installation prerequisites? Review the prerequisites documentation for guidance.
Although system requirements are mostly the same for LME 2.0, documentation highlighting them is available on LME’s GitHub page. 

**14. Where Can I Receive Further Support?**

For further support with LME 2.0 users can explore the following options:
•	Report LME issues via the GitHub 'Issues' tab at the top of the page or by clicking GitHub Issues
•	Visit GitHub 'Discussions' to check if your issue has been addressed or start a new thread
•	Directly email CyberSharedServices@cisa.dhs.gov for other questions or comments

**15. Where Can I Find Additional Resources?**

Please visit (CISA’s LME website)[https://www.cisa.gov/resources-tools/services/logging-made-easy] for additional resources.
                   
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

