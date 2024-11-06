# LME Agent Enrollment Guide

This guide will walk you through the process of enrolling an agent in the LME system.

## Steps to Enroll an Agent

1. **Access the Fleet Menu**
   - Open the LME dashboard
   - Scroll down and select "Fleet" from the menu

2. **Add a New Agent**
   - Click on the "Add agent" button

3. **Select the Policy**
   - Ensure you select the appropriate policy for the agent
   - For example, choose "Endpoint Policy" if you're adding an endpoint device

4. **Enrollment Settings**
   - Keep the "Enroll in Fleet" option selected

5. **Choose the Agent Type**
   - Select the appropriate option based on your endpoint:
     - Linux Tar
     - Mac
     - Windows (ensure you run this in a powershell prompt with administrator privileges)

6. **Installation Command**
   - You will be presented with an installation command for the selected platform
   - Note: If you haven't added the LME certificates to your trusted store, you'll need to modify the command

7. **Modify the Command (If necessary. You will need to do this if you haven't add certificates to the trusted store)**
   - Add `--insecure` at the end of the `./elastic-agent install` command
   - This is similar to clicking "continue to website" in a browser when you get a certificate warning
   - Example:
     ```
     ./elastic-agent install [-other-flags-youll-see] --insecure
     ```
     
   - it should look like this screenshot:
![example-screenshot](/docs/imgs/insecure-powershell.png)

8. **Execute the Command**
   - Recommend running each line individually so you can see a clear picture of the status of each command ran. The entire process will download an agent, unzip it, and install it.

From Fleet you should see the agent enrolled now.

# LME Elastic Agent Integration Example

This guide will walk you through the process of adding a Windows integration to an agent policy in the LME system.

## Steps to Add Windows Integration

1. **Access Fleet and Agent Policies**
   - Open the LME dashboard
   - Select "Fleet" from the menu
   - Click on "Agent policies"

2. **Select the Target Policy**
   - Choose the policy you want to add the integration to
   - For example, select "Endpoint Policy"

3. **Add Integration**
   - Click the "Add integration" button

4. **Choose Windows Integration**
   - From the list of available integrations, select "Windows"

5. **Configure Windows Integration**
   - Scroll down to review the options available
   - You'll see various Windows logs and metrics that can be collected

6. **Customize Log Collection**
   - Review the options set to on or off
   - These options provide more choices for collecting Windows logs
   - Important note: If you have Sysmon installed on your endpoints, ensure "Sysmon Operational" is selected to collect Sysmon logs

7. **Configure Metrics Collection**
   - You can choose to collect various metrics from your Windows endpoints
   - Review and enable the metrics you're interested in monitoring

8. **Save and Deploy**
   - After configuring your desired options, save the integration
   - Deploy the changes to apply them to the agents using this policy

## Important Considerations

- **Sysmon Integration**: If you're using Sysmon for enhanced logging, make sure to enable the Sysmon Operational log collection
- **Performance Impact**: Be mindful that collecting more logs and metrics may impact endpoint performance. Balance your monitoring needs with system resources
- **Regulatory Compliance**: Consider any regulatory requirements you may have when selecting which logs and metrics to collect
- **Storage Considerations**: More data collection means more storage usage. Ensure your LME system has adequate storage capacity
- **Review Regularly**: Periodically review your integration settings to ensure they still meet your needs and adjust as necessary

By following these steps, you can effectively add and configure the Windows integration to your chosen agent policy in the LME system, allowing for comprehensive logging of your Windows endpoints.

Apply these same steps to future integrations such as Auditd for Linux.
