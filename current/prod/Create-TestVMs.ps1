
<#PSScriptInfo

.VERSION 2.2

.GUID f35cd072-b739-4542-8fbf-3976b8daa444

.AUTHOR Jeff Gilbert (@JeffGilb)

.COMPANYNAME Microsoft

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0: Original published version.
Version 1.1: Minor bug fixes.
Version 1.2: Minor bug fixes.
Version 1.3: Minor bug fixes.
Version 2.0: Added version to PowerShell console title.
             Added capability to accept or change Hyper-V host save locations. 
             Set file and folder browse dialogs to always open on top.
             Added final summary confirmation prompt before creating VMs with options to exit.
             Added a virtual network configuration selector dialog. No virtual network selected by default.
             Added differencing disk support:
             - Allows selection of a master (sysprepped) VHDX to be used as the master disk for new VMs
             - Creates an OOBE snapshot while turned off for VMs using differencing disks
             - Creates a master directory with a copy of the selected VHDX.
             - Creates a readme file in the master disk directory listing VMs using the master disk
             - Puts the master VHDX and SN in the VM notes in Hyper-V
Version 2.1: Bug fix to address concatonating paths and virtual network names.
Version 2.2: Fixed network switch assignment issue.
  
.DESCRIPTION 
 Script to automate the creation of test Hyper-V VMs. 
#>

#################################### DEFAULT PARAMETERS #######################################

# Edit these to set defaults for the script to use:

param(
    [Parameter(Mandatory=$False)] [String] $VMPath = "C:\ProgramData\Microsoft\Windows\Hyper-V\",
    [Parameter(Mandatory=$False)] [String] $HDPath = "C:\Users\Public\Documents\Hyper-V\Virtual Hard Disks\",
    [Parameter(Mandatory=$False)] [String] $vhdx = "",
	[Parameter(Mandatory=$False)] [Int]    $RAM = 2, # 2GB = 2*1073741824
    [Parameter(Mandatory=$False)] [String] $VMSwitch = "Default Switch",
    [Parameter(Mandatory=$False)] [String] $ISO = "",
    [Parameter(Mandatory=$False)] [String] $VMPrefix = "Autopilot",
    [Parameter(Mandatory=$False)] [String] $VMnumber = "1"
)

#region ############################## FOLDER AND FILE BROWSER FUNCTIONS ###############################

Function Get-Folder 
{

    Add-Type -AssemblyName System.Windows.Forms
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
    $folderbrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        description = "Select a folder"
        rootfolder = "Desktop"
        SelectedPath = $initialDirectory
        }
    $result = $folderbrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK){
        $folder = $FolderBrowser.SelectedPath
    }
    else {
        return
    }
    return $folder
}    

Function Get-File
{

    Add-Type -AssemblyName System.Windows.Forms
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Title = "Select the ISO file to mount."
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Multiselect = $false # Multiple files cannot be chosen
	    Filter = 'ISO Files (*.ISO)|*.ISO' # Specified file types
        }
    $result = $fileBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK){
        $file = $fileBrowser.SelectedPath
    }
    else {
        return
    }
    
    $file = $fileBrowser.FileName;
    return $file
}

Function Get-VHDX
{

    Add-Type -AssemblyName System.Windows.Forms
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Title = "Select the parent VHDX to use when creating differencing disks."
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Multiselect = $false # Multiple files cannot be chosen
	    Filter = 'VHDX Files (*.VHDX)|*.VHDX' # Specified file types
        }
    $result = $fileBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK){
        $vhdx = $fileBrowser.SelectedPath
    }
    else {
        return
    }
    
    $vhdx = $fileBrowser.FileName;
    return $vhdx
}

$Version = "Create-TestVMs v2.0"
$host.ui.RawUI.WindowTitle = $Version

#endregion ********************************************************************************************

#region ############################# VIRTUAL MACHINE STORAGE LOCATIONS ###############################

CLS 
write-host `n
write-host "                          Virtual Machine Storage Locations                          "`n -ForegroundColor White -BackgroundColor Black 

$vmpath = ""
$vmpath = get-vmhost | Select-Object -Property VirtualMachinePath
$vmpath = """?($vmpath)"""
$vmpath = $vmpath.remove(0,24)
$vmpath = $vmpath.trimStart("=")
$vmpath = $vmpath.trimend("\})""")

$hdpath = ""
$hdpath = get-vmhost | Select-Object -Property VirtualHardDiskPath 
$hdpath = """?($hdpath)"""
$hdpath = $hdpath.remove(0,24)
$hdpath = $hdpath.trimStart("=")
$hdpath = $hdpath.trimend("\})""")

write-host "The Hyper-V host machine is set to store VMs at these default locations:`n" 
write-host -ForeGroundColor Green "`tVM configuration files:`t" $vmpath"`n`n`tVM hard disk files:`t $HDpath"`n""

write-host -ForeGroundColor Yellow "Do you want to change the default storage settings?"
$Readhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($ReadHost){ 
        Y {
           write-host -ForeGroundColor Yellow " Do you want to change the host defaults for where to store VMs?" 
           $VMReadhost = Read-Host " [Y] [N] (Default is N)"
           Switch ($VMReadhost){
             Y {
                $VMfolder = Get-Folder
                If ($VMfolder){$VMPath = $VMfolder}
                write-host -ForegroundColor Green "Virtual Machine path will be: $VMPath.`n"
               }
             N {} # Use default setting.
          } 
                   
           If ($VMReadhost -ne "y"){write-host -ForegroundColor Green "`nDefault VM storage setting will be used.`n"}        
           
           write-host -ForeGroundColor Yellow "Do you want to change the host defaults for where to store VM hard disks?" 
           $HDReadhost = Read-Host " [Y] [N] (Default is N)"
           Switch ($HDReadhost){
             Y {
                $HDfolder = Get-Folder
                If ($HDfolder){$HDPath = $HDfolder}
                write-host -ForegroundColor Green "`nVirtual Machine hard disk path will be: $HDPath.`n"
               }
             N {} # Use default setting.
             }
        If ($HDReadhost -ne "y"){write-host -ForegroundColor Green "`nDefault VM hard disk storage setting will be used.`n"}     
      }
    }
       
    If ($ReadHost -ne "y"){write-host -ForeGroundColor Green "`nHyper-V host default settings will be used.`n"}
        Else{
             write-host "`nThe Hyper-V host machine will be set to store VMs at these default locations:`n" 
             write-host -ForeGroundColor Green "`tVM configuration files:`t" $vmpath"`n`n`tVM hard disk files:`t $HDpath"`n""
            }
#endregion ********************************************************************************************

#region ################################## HARD DISK CONFIGURATION #####################################

write-host "                                VM Hard Disk Options                                 "`n -ForegroundColor White -BackgroundColor Black 

# Prompt for master VHDX to use for differencing disks
write-host -ForeGroundColor Yellow "Do you have a sysprepped VHDX to use as a master for differencing disks?"
$VHDXReadhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($VHDXReadHost){ 
        Y { 
            write-host "`nBrowse to and select your sysprepped .VHDX. This will be used as the master image for differencing disks.`n"      
            $vhdx = get-vhdx
            If ($vhdx){
                $nameEnd = get-random -Minimum 100 -Maximum 999 
                write-host -ForegroundColor Green "A copy of "$vhdx" will be used to create the master VHDX image in the Master-"$nameEnd "directory of the VM hard disk storage location.`n"
                $masterVHDX = $HDPath+"\" + "Master-"+$nameEnd
                $masterSource = $vhdx          
            }
            Else {Write-host -ForegroundColor Green "Browse cancelled by user. Differencing disks will not be used.`n";  $vhdx = ""}	
          }
        N {}
     }
     
     If ($VHDXReadhost -ne "y"){write-host -ForegroundColor Yellow "`n"Differencing disks will not be used."`n"}  
     
#endregion ********************************************************************************************
   
#region ###################################### RAM TO ASSIGN ###########################################

write-host "                              Amount of RAM For New VMs                              "`n -ForegroundColor White -BackgroundColor Black 

$getName = Get-WmiObject -Class win32_computersystem -ComputerName . | Select-Object -Property Name
$getName = """?($getName)"""
$getName = $getName.trimStart("""?(@{Name=")
$getName = $getName.trimend("})""")

write-host "The default amount of RAM to assign to VMs is" $RAM"GB.`nYour Hyper-V host," $getName", has the following amount of RAM to assign:"
Get-WmiObject -Class win32_computersystem -ComputerName . | fl @{Name="Available memory (GB)";e={[math]::truncate($_.TotalPhysicalMemory /1GB)}}
write-host "Do you want to change the amount of RAM assigned to VMs?" -ForegroundColor Yellow 
$Readhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($ReadHost) 
     { 
       Y {
         $inputValue = ""
         do {
             $inputValid = [int]::TryParse((Read-Host "`nHow many Gigabytes of RAM do you want to assign to VMs?"), [ref]$inputValue) 
             if (-not $inputValid) {
             Write-Host "Enter a valid number..." -ForegroundColor Red
            }
         } 
         while (-not $inputValid)
         write-host  -ForegroundColor Green "`nVMs will be created with "$inputValue"GB of RAM.`n"
         $RAM = $inputValue
         }     
       N {write-host  -ForegroundColor Green "`n Default selected.`n"}  

   } 
         $RAMAssigned = $RAM * 1073741824 # "Default 2GB = 2 * 1073741824 (2,147,483,648)."
         if ($Readhost){} else{write-host -ForegroundColor Green "`n Default selected. `n"}

#endregion ********************************************************************************************

#region ##################################### NETWORK SWITCH ##########################################

write-host "                               Virtual Network Switch                                "`n -ForegroundColor White -BackgroundColor Black 

write-host "`nDo you want to put the VMs on a virtual switch?" -ForegroundColor Yellow 
$Readhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($ReadHost) 
     { 
       Y {
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            $form = New-Object System.Windows.Forms.Form
            $form.Text = 'Virtual Switch'
            $Form.TopMost    = $true
            $form.Size = New-Object System.Drawing.Size(300,200)
            $form.StartPosition = 'CenterScreen'
            $okButton = New-Object System.Windows.Forms.Button
            $okButton.Location = New-Object System.Drawing.Point(75,120)
            $okButton.Size = New-Object System.Drawing.Size(75,23)
            $okButton.Text = 'OK'
            $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.AcceptButton = $okButton
            $form.Controls.Add($okButton)
            $cancelButton = New-Object System.Windows.Forms.Button
            $cancelButton.Location = New-Object System.Drawing.Point(150,120)
            $cancelButton.Size = New-Object System.Drawing.Size(75,23)
            $cancelButton.Text = 'Cancel'
            $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $form.CancelButton = $cancelButton
            $form.Controls.Add($cancelButton)
            $label = New-Object System.Windows.Forms.Label
            $label.Location = New-Object System.Drawing.Point(10,20)
            $label.Size = New-Object System.Drawing.Size(280,20)
            $label.Text = 'Select a virtual switch to use:'
            $form.Controls.Add($label)
            $listBox = New-Object System.Windows.Forms.ListBox
            $listBox.Location = New-Object System.Drawing.Point(10,40)
            $listBox.Size = New-Object System.Drawing.Size(260,20)
            $listBox.Height = 80

            $swi = get-vmswitch | Select-Object -Property Name
            write-host
            ForEach ($item in $swi) {

            $item = """?($item)"""
            $item = $item.Remove(0,10);
            $item = $item.trimEnd("})""")

            [void] $listBox.Items.Add($item)
            } 

            $form.Controls.Add($listBox)
            $form.Topmost = $true
            $result = $form.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK)
            {
                $x = $listBox.SelectedItem
                if($x){$SwitchToUse = $x;$VMSwitch=$x;write-host -ForegroundColor Green "$VMSwitch will be used." }
                Else{$VMSwitch = "No virtual switch selected.";write-host -ForegroundColor Green $VMSwitch`n}
            }
            $VMSwitch = $SwitchToUse
            if ($result -eq [System.Windows.Forms.DialogResult]::Cancel)    
            {$VMSwitch = "No virtual switch selected.";write-host -ForegroundColor Green $VMSwitch`n}   
        }
       N {}  
     } 
     If ($readhost -ne "y"){
                            $VMSwitch = "No virtual switch selected."
                            write-host -ForeGroundColor Green "$VMSwitch`n" 
                           }

#endregion ********************************************************************************************

#region ######################################### ISO #################################################
write-host "`n" 
write-host "                                Operating System ISO                                 "`n -ForegroundColor White -BackgroundColor Black  

write-host "`nDo you want to mount an Operating System .ISO?" -ForegroundColor Yellow 
$Readhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($ReadHost) 
     { 
       Y {
        $file = Get-File
        If ($file){$ISO = $file;write-host -ForegroundColor Green `n"The VM will be set to boot from: $ISO.`n"}
        Else {Write-host -ForegroundColor Green "`nBrowse cancelled by user. No .ISO will be mounted.";  $ISO = "No .ISO selected."}	
        }
       N {}  
     } 
     If ($readhost -ne "y"){
                            $ISO = "No .ISO selected."
                            write-host "`n"
                            write-host -ForegroundColor Green "An .ISO will not be mounted.`n" 
                           }

#endregion ***********************************************************************************************

#region #################################### NAMING PREFIX ############################################

write-host "                            Virtual Machine Naming Prefix                            "`n -ForegroundColor White -BackgroundColor Black   

write-host "`nThe VM name prefix will be followed by -999 where 999 is three random numbers.`n"   -ForegroundColor Yellow

$Prefix = read-host "Enter a VM naming prefix (default is $VMPrefix)"
If ($Prefix -ne ""){$VMPrefix = $Prefix}
Write-host -ForegroundColor Green "`nVM names will start with $VMPrefix.`n"

#endregion ***********************************************************************************************

#region ################################ NUMBER OF VMs TO CREATE ######################################

write-host "                               Number of VMs to Create                               "`n -ForegroundColor White -BackgroundColor Black 
 
write-host -ForegroundColor Yellow "`nHow many VMs do you want to create?`n"         
    $inputValue = ""
    do {
        $inputValid = [int]::TryParse((Read-Host "Enter the number of VMs to create"), [ref]$inputValue)
        if (-not $inputValid) {
        Write-Host "Enter a valid number..." -ForegroundColor Red
       }
       } 
       while (-not $inputValid)
       $VMNumber = $inputValue 
       write-host -ForegroundColor Green `n"$VMNumber VMs will be created.`n"

start-sleep -seconds 2;CLS # Give time to read last confirmation before clearing screen.

#endregion ********************************************************************************************

#region ###################################### SUMMARY ################################################

write-host "                                     Summary                                         "`n -ForegroundColor White -BackgroundColor Black  

write-host -ForegroundColor Cyan "`nVMs will be stored here:        "$VMPath  
write-host -ForegroundColor Cyan "Hard disks will be stored here: "$HDPath
If ($vhdx -ne ""){write-host -ForegroundColor Cyan "Differencing disks master at:   "$masterVHDX}  
write-host -ForegroundColor Cyan "VMs will have this much RAM:    "$RAM"GB"
write-host -ForegroundColor Cyan "Network switch to use:          "$VMSwitch
write-host -ForegroundColor Cyan "This .ISO will be mounted:      "$ISO
write-host -ForegroundColor Cyan "VM names will start with:       "$VMPrefix
write-host -ForegroundColor Cyan "Number of VMs to create:        "$VMnumber

Write-host -ForeGroundColor Cyan "`n`nTo modify the default values used by the script, edit the default parameter`nsettings at the top of the script. If you installed the script using the `nInstall-Script Create-TestVMs PowerShell command, the script can be found at `n$env:ProgramFiles\WindowsPowerShell\Scripts.`n"


write-host -ForeGroundColor Green "`nReady to create VMs!`n"
write-host -ForeGroundColor Yellow "Continue (Y) or Cancel (N)?"
$Readhost = Read-Host " [Y] [N] (Default is Y)"  
    Switch ($ReadHost) 
     { 
       Y {}
       N {return}  
     }
     If ($readhost -ne "n"){}

#endregion ********************************************************************************************

#region ##################################### CREATE VMs ##############################################

# If alternate VM storage paths were provided, update them on the hyper-v host now:
Set-VMHost -VirtualMachinePath $vmpath
Set-VMHost -VirtualHardDiskPath $hdpath

# Using differencing disks            
If($vhdx -ne "")
    {
        $masterVHDX = $HDPath+"\Master-"+$nameEnd+"\"
        # Create master directory
        new-item $masterVHDX -ItemType Directory
        # Copy master VHDX into master directory
        write-host "Copying master hard disk file...`n"
        # Copy-Item -Path $vhdx -Destination $masterVHDX
        Start-BitsTransfer -Source $vhdx -Destination $masterVHDX -Description "Copying $vhdx to $masterVHDX" -DisplayName "Copying master hard disk file."
        #Set the parent VHDX as Read-Only
        Set-ItemProperty -Path $masterVHDX"\*.vhdx" -Name IsReadOnly -Value $true
        Add-Content $masterVHDX"ReadMe.txt" "These VMs are using differencing disks based on this master disk:"
              
    for ($i=1; $i -le $VMnumber; $i++)
        {
        $VMSuffix = get-random -minimum 100 -maximum 999
        $VMname = $VMPrefix + "-" + $VMSuffix
        # Create differencing disk in HD location
        $masterVhdxName = Get-ChildItem $masterVHDX*.vhdx | Select-Object -ExpandProperty Name
        write-host "Creating differencing disk for"$VMName"...`n"
        $parentPath = $masterVHDX+$masterVhdxName  
        $vhdPath = $HDPath + "\" + $vmname + "\" + $vmname + ".vhdx"
        $vhdxDiff = New-VHD -Path $vhdPath -ParentPath $parentPath -Differencing
        
        # Create VM, but first check for network switch
        If ($VMSwitch -ne "No virtual switch selected."){
            new-vm -Name $VMName -Path $VMPath"\" -Generation 2 -VHDPath $vhdPath -BootDevice VHD -MemoryStartupBytes $RAMAssigned -SwitchName $VMSwitch
        }
        Else{   
            new-vm -Name $VMName -Path $VMPath"\" -Generation 2 -VHDPath $vhdPath -BootDevice VHD -MemoryStartupBytes $RAMAssigned     
            }    
        
        # Adding an ISO to the VM?
        If ($ISO -ne "No .ISO selected."){
            Add-VMDvdDrive -VMName $VMname -Path $ISO
            $bootorder = (Get-VMFirmware -VMName $vmname).bootorder | Sort-Object -Property Device
            Get-VM -VMName $VMname | Set-VMFirmware -BootOrder $bootorder}
        Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
        Enable-VMTPM -VMName $VMName
        Set-VM -Name $VMName -ProcessorCount 4 -SmartPagingFilePath $HDPath -AutomaticStartAction StartIfRunning -DynamicMemory 
        
        # Add VM SN# to Hyper-V VM notes to make it easier to find for Autopilot maintenance.
        $sn = Get-WmiObject -ComputerName . -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData `
            | ? {$_.elementName -eq $VMName} `
            | Select -ExpandProperty BIOSSerialNumber        
        $vm = Get-VM -Name $VMName
        Set-VM -VM $vm -Notes "$($vm.Notes) VM serial number is: $sn." -Confirm:$false
        
        # Add master disk location used by differencing disk to VM notes
        Set-VM -VM $vm -Notes "$($vm.Notes) `n`nThis VM is using differencing disks. Its master disk is located at $masterVHDX." -Confirm:$false

        #Checkpoint the VM at pre-out of box experience state.
        write-host "Creating OOBE checkpoint"
        Get-VM $VMName -ComputerName . | checkpoint-vm -SnapshotName "OOBE"
        write-host "Starting "$VMName`n
        Start-VM $VMname
        Add-Content $masterVHDX"ReadMe.txt" $VMname     
        }        
    } 
# Not using differencing disks
Else{
    for ($i=1; $i -le $VMnumber; $i++)
        {
        $VMSuffix = get-random -minimum 100 -maximum 999
        $VMname = $VMPrefix + "-" + $VMSuffix
        
        # Create VM, but first check for network switch
        If ($VMSwitch -ne "No virtual switch selected."){
            New-VM -Name $VMname -Path $VMpath -Generation 2 -NewVHDSizeBytes 127GB -NewVHDPath "$HDPath\$vmname.vhdx" -MemoryStartupBytes $RAMAssigned -SwitchName $VMSwitch
        }
        Else{   
            New-VM -Name $VMname -Path $VMpath -Generation 2 -NewVHDSizeBytes 127GB -NewVHDPath "$HDPath\$vmname.vhdx" -MemoryStartupBytes $RAMAssigned     
            }  
                 
        # Adding an ISO to the VM?
        If ($ISO -ne "No .ISO selected."){
            Add-VMDvdDrive -VMName $VMname -Path $ISO
            $bootorder = (Get-VMFirmware -VMName $vmname).bootorder | Sort-Object -Property Device
            Get-VM -VMName $VMname | Set-VMFirmware -BootOrder $bootorder}
        Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
        Enable-VMTPM -VMName $VMName
        Set-VM -Name $VMName -ProcessorCount 4 -SmartPagingFilePath $HDPath -AutomaticStartAction StartIfRunning -DynamicMemory 

        # Add VM SN# to Hyper-V VM notes to make it easier to find for Autopilot maintenance.
        $sn = Get-WmiObject -ComputerName . -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData `
            | ? {$_.elementName -eq $VMName} `
            | Select -ExpandProperty BIOSSerialNumber        
        $vm = Get-VM -Name $VMName
        Set-VM -VM $vm -Notes "$($vm.Notes) VM serial number is: $sn." -Confirm:$false
                 
        }        
        write-host -ForegroundColor Cyan "Created $vmname!"
        Start-VM $VMname
        start-sleep 1
    }
    
    write-host -ForegroundColor Green "`n`nComplete!`n"

#endregion ********************************************************************************************
    
exit
