---
last.updated: 5/7/2020
---

<link rel="shortcut icon" type="image/x-icon" href="favicon.ico">

# Create-TestVMs

Documentation for the Create-TestVMs PowerShell script available in the [PowerShell Gallery](https://www.powershellgallery.com/packages/Create-TestVMs/1.3).

This script was created to help automate the creation of Hyper-V VMs for Windows Autopilot testing. However, the script will create Hyper-V VMs for any purpose you need. Run the script with administrative privileges on your Hyper-V host machine.

## What it does

When the script is run, it will prompt you for the VM settings necessary to create a Hyper-V VM. It will then create, and start, as many VMs as you ask for using the provided naming prefix to begin the VM name. If you do not change the default values at the top of the script, it will create and start a VM named Autopilot-*999*, where *999* is a three digit random number, with 2GB of RAM and the VM config files and hard disks stored in the Hyper-V default locations. 

When creating VMs, you can create each with their own full VHDX file and boot from an operating system ISO to install Windows, or choose to create VMs using differencing disks by selecting a master, sysprepped Windows image. You can accept or modify the default values when prompted as the script runs for other options. All questions have default values if you just hit enter. To modify the default values used by the script, edit the default parameter settings at the top of the script. If you installed the script using the **Install-Script Create-TestVMs** PowerShell command, the script can be found at *$env:ProgramFiles\WindowsPowerShell\Scripts*.

Here's what it looks like to build 5 VMs using differencing disks in about 2:30:

[![Create-TestVMs](.\create-testvms.PNG)](.\5VMsDifferencingDisks.mp4 "5 VMs at OOBE in less than three minutes")

Individual VMs booting from an ISO is even faster. About a minute:

[![Create-TestVMs](.\create-testvms.PNG)](5VMsISO.mp4 "5 VMs from ISO in 1 minute")

Feedback or suggestions for improvements? Find me on Twitter [@jeffgilb](https://twitter.com/jeffgilb). 

## The current version of the script is 1.3.
Get it from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Create-TestVMs/1.3) by running the *Install-Script Create-TestVMs* command.

# Release notes
<details>
  <summary>Version 1</summary>

<dl>
  <dt>v1.0</dt>
  <dd>Initial release</dd>
  <dt>v1.1</dt>
  <dd> Minor bug fixes</dd>
  <dt>v1.2</dt>
  <dd> Minor bug fixes</dd>
  <dt>v1.3</dt>
  <dd> Minor bug fixes</dd>
  </dl>
</details>

<details>
  <summary>Version 2</summary>

<dl>
  <dt>In development:</dt>
  <dd>• Version displayed in PowerShell console title<br>• Ability to use and set the Hyper-V host's default VM storage settings instead of Hyper-V defaults<br>• Ability to use custom VHDX files with differencing disks<br>• Ability create VMs without a network connection</dd>
</dl>
</details>
