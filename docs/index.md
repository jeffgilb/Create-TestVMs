---
last.Updated: 5/7/2020
---


# Create-TestVMs
Documentation for the Create-TestVMs PowerShell script available in the [PowerShell Gallery](https://www.powershellgallery.com/packages/Create-TestVMs/1.3).

This script was created to help automate the creation of Hyper-V VMs for Windows Autopilot testing. However, the script will create Hyper-V VMs for any purpose you need. Run the script with administrative privileges on your Hyper-V host machine.

## What it does
When the script is run, it will prompt you for the VM settings necessary to create a Hyper-V VM. It will then create, and start, as many VMs as you ask for using the provided naming prefix to begin the VM name. If you do not change the default values at the top of the script, it will create and start a VM named Autopilot-*999*, where *999* is a three digit random number, with 2GB of RAM and the VM config files and hard disks stored in the Hyper-V default locations. 

## Default values
If you do not modify the defaults when prompted when the script runs, the following default values will be used:

|Parameter|Default value|Description|
|-----|-----|-----|
|**$VMPath**|C:\ProgramData\Microsoft\Windows\Hyper-V|This is the default Hyper-V setting for where VM configuration files are stored. You can browse to the location to save VM config files when the script runs.|
|**$HDPath**|C:\Users\Public\Documents\Hyper-V\Virtual Hard Disks|Where the VM hard disks will be stored. This is the Hyper-V server default location. When the script runs, you can browse to the location to save VM hard disks.|
|**$RAM**|2|Amount of RAM in Gigabytes to assign to new VMs. When the script runs, it will tell you how much RAM is available on your host to help you decide (2GB = 2*1073741824).|
|**$VMSwitch**|Default Switch|Name of the Hyper-V virtual switch to use. When the script runs, it will tell you what virtual switches are available on your Hyper-V host to help you decide.|
|**$ISO**|None assigned by default|ISO file to mount on new VMs. You can browse to the location of the ISO when the script runs.|
|**$VMPrefix**|Autopilot|Name prefix for new VMs. Followed by -*<3 random numbers>* when the VM is created.|
|**$VMnumber**|1|Number of VMs to create.|
|   |   |   |

You can accept or modify the default values when prompted as the script runs.

To modify the default values used by the script, edit the default parameter settings at the top of the script. If you installed the script using the **Install-Script Create-TestVMs** PowerShell command, the script can be found at *$env:ProgramFiles\WindowsPowerShell\Scripts*.

Feedback or suggestions for improvements? Find me on Twitter [@jeffgilb](https://twitter.com/jeffgilb). 

## The current version of the script is 1.3.
Get it from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Create-TestVMs/1.3) by running the *Install-Script Create-TestVMs* command.

# Release notes
<details>
  <summary>Version 1</summary>
  
  * Version 1.0: Initial release<br>
  * Version 1.1: Minor bug fixes<br>
  * Version 1.2: Minor bug fixes<br>
  * Version 1.3: Minor bug fixes<br>
</details>

<!--

<details>
  <summary>Version 1 Release notes</summary>

### Version 1.0

* Original published version.

### Versions 1.1 - Version 1.3

* Minor bug fixes.

### Coming in v2

* Version displayed in PowerShell console title
* Ability to use and set the Hyper-V host's default VM storage settings instead of Hyper-V defaults
* Ability to use custom VHDX files with differencing disks
* Ability create VMs without a network connection

</details>
-->