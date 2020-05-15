---
last.updated: 5/15/2020
--- 

# Create-TestVMs

**THIS IS AN ARCHIVE REPOSITORY**

This repo is used as an archive for the Create-TestVMs PowerShell script available in the PowerShell Gallery. It's not where you should get the script from.

To get the most current version, open a PowerShell console and enter: **Install-Script Create-TestVMs**

That will install the script from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Create-TestVMs/2.0).

Documentation for the Create-TestVMs script is at: https://create-testvms.jeffgilb.com/.

## What it does
This script was created to help automate the creation of Hyper-V VMs for Windows Autopilot testing. However, the script will create Hyper-V VMs for any purpose you need.

    Run the script with administrative privileges on your Hyper-V host machine.

When the script is run, it will prompt you for the VM settings necessary to create a Hyper-V VM. It will then create, and start, as many VMs as you ask for using the provided naming prefix to begin the VM name. If you do not change the default values at the top of the script, it will create and start a VM named Autopilot-*999*, where *999* is a three digit random number, with 2GB of RAM and the VM config files and hard disks stored in the Hyper-V host machine's default locations. You can use individual hard disks for each VM or differencing disks from a master, sysprepped, VHDX that you specify when the script runs.

Feedback or suggestions for improvements? Find me on Twitter [@jeffgilb](https://twitter.com/jeffgilb). 