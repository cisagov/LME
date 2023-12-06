# Snapshot Scripts

This folder contains scripts for managing Azure VM snapshots.

### Notes

- Replace the parameters in the usage examples with your actual values.
- Make sure to run these scripts in an Azure PowerShell environment in a shell at Azure.

## Scripts

### CreateSnapshots.ps1
Description: 

Creates snapshots of the VMs in the specified resource group

Usage:
```powershell
.\CreateSnapshots.ps1 `
   -resourceGroup "MyResourceGroup" `
   -versionSuffix "1.1.0" `
   -targetResourceGroup "TestbedAssets-regioncode"
```

### CreateVmFromSnapshot.ps1
 Description: 
 
 This script will create a new VM from a snapshot.  
 It is designed to test the snapshot restore process so that we can incorporate it into the create script.
 It will create a new managed disk from the snapshot and then create a new VM using the new disk.

Usage:
```powershell
.\CreateVmFromSnapshot.ps1 `
    -SnapshotName "MySnapshot" `
    -ResourceGroup "MyResourceGroup" `
    -OsType "windows" # or "linux"
```

### CopySnapshotToRegions.ps1

 Description: 
 
 This script copies a snapshot to multiple regions.  
 You will want to run it for each of the virtual machine snapshots you create. 
 So they will be available to all the regions you want to test in.
 Then copy the outputs from the script and put them into the corresponding places 
 in the SetupTestbed.ps1 script.

Usage:
```powershell
.\CopySnapshotToRegions.ps1 `
    -snapshotName "SnapshotName" `
    -version "1.1.0" `
    -sourceResourceGroup "TestbedAssets-centralus" 
```
