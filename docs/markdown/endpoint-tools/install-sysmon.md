# Installing Sysmon on Windows Machines

This guide will walk you through the process of installing Sysmon (System Monitor) on your Windows machines using the SwiftOnSecurity configuration.

## Prerequisites

- Administrative access to the Windows machine
- Internet connection to download necessary files

## Step 1: Download Sysmon

1. Visit the official Microsoft Sysinternals Sysmon page: https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon
2. Click on the "Download Sysmon" link to download the ZIP file.
3. Extract the contents of the ZIP file to a folder on your computer (e.g., `C:\Sysmon`).

## Step 2: Download SwiftOnSecurity Configuration

1. Open a web browser and go to: https://github.com/SwiftOnSecurity/sysmon-config/blob/master/sysmonconfig-export.xml
2. Click the button to download raw content.
3. Save the file into the Symon directory.

## Step 3: Install Sysmon

1. Open an elevated Command Prompt (Run as Administrator).
2. Navigate to the folder where you extracted Sysmon:
   ```
   cd C:\Sysmon
   ```
3. Run the following command to install Sysmon with the SwiftOnSecurity configuration:
   ```
<<<<<<< HEAD
   sysmon -accepteula -i sysmonconfig-export.xml
=======
   sysmon64.exe -accepteula -i sysmonconfig-export.xml
>>>>>>> release-2.0.0
   ```

## Step 4: Verify Installation

1. Open Event Viewer (you can search for it in the Start menu).
2. Navigate to "Applications and Services Logs" > "Microsoft" > "Windows" > "Sysmon" > "Operational".
3. You should see events being logged by Sysmon.

## Updating Sysmon Configuration

To update the Sysmon configuration in the future:

1. Download the latest `sysmonconfig-export.xml` from the SwiftOnSecurity GitHub repository.
2. Open an elevated Command Prompt.
3. Navigate to the Sysmon folder.
4. Run the following command:
   ```
<<<<<<< HEAD
   sysmon -c sysmonconfig-export.xml
=======
   sysmon64.exe -c sysmonconfig-export.xml
>>>>>>> release-2.0.0
   ```

## Uninstalling Sysmon

If you need to uninstall Sysmon:

1. Open an elevated Command Prompt.
2. Navigate to the Sysmon folder.
3. Run the following command:
   ```
<<<<<<< HEAD
   sysmon -u
=======
   sysmon64.exe -u
>>>>>>> release-2.0.0
   ```

## Additional Notes

- You can now enable sysmon log collection from the Windows elastic agent integration.
<<<<<<< HEAD
- Use a shared folder, SCCM, GPO's, or other tools to install are large quantities of machines.
=======
- Use a shared folder, SCCM, GPO's, or other tools to install are large quantities of machines.
>>>>>>> release-2.0.0
