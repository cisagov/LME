
## Guide to Organizational Units

What is an Organizational Unit?
An Organizational Unit is a folder that contains Users, Computers and groups.
You can use OUs to select a subset of computers that you want to be included in the LME Client group for testing before rolling out LME site wide.

### 1 - How to make an OU
**1.1** Open the Group Policy Management Console by running ```gpmc.msc```. You can run this command by pressing Windows key + R.

![import a new object](/docs/imgs/gpo_pics/gpmc.jpg)
<p align="center">
Figure 1: Launching GPMC
</p>

:hammer_and_wrench: If you receive the error `Windows cannot find 'gpmc.msc'`, see [Troubleshooting: Installing Group Policy Management Tools](/docs/markdown/reference/troubleshooting.md#installing-group-policy-management-tools).

**1.2** Right click on the domain and select "New Organizational Unit" as seen below.

![making new ou](/docs/imgs/gpo_pics/new_ou.jpg)
<p align="center">
Figure 2: Making a new OU
</p>

### 2 - Adding clients/servers to OU

To add Client machines, Servers or Security Groups to a specified OU:

- Open Active Directory Users and Computers (run `dsa.msc` in the "Run" dialogue box).
- Find the machine(s) that you wish to be in the group and drag and drop the machines into the group.

![import finished](/docs/imgs/gpo_pics/aduc.jpg)
<p align="center">
Figure 3: Open Active Directory Users and Computers
</p>

:hammer_and_wrench: If you receive the error `Windows cannot find dsa.msc`, see [Troubleshooting: Installing Active Directory Domain Services](/docs/markdown/reference/troubleshooting.md#installing-active-directory-domain-services)
