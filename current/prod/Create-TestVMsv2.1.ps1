
<#PSScriptInfo

.VERSION 2.1

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
            
            <# Adds an icon to PowerShell forms:
            $iconBase64      = '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'
            $iconBytes       = [Convert]::FromBase64String($iconBase64)
            $iconImage       = [System.Drawing.Image]::FromStream($stream, $true)
            $Form.Icon       = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())
            $stream          = New-Object IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
            $stream.Write($iconBytes, 0, $iconBytes.Length);
            #>
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
                Else{$VMSwitch = "No virtual switch selected.";write-warning $VMSwitch`n}
            }
            $VMSwitch = $SwitchToUse
            if ($result -eq [System.Windows.Forms.DialogResult]::Cancel)    
            {$VMSwitch = "No virtual switch selected.";write-warning $VMSwitch`n}   
        }
       N {}  
     } 
     If ($readhost -ne "y"){
                            $VMSwitch = "No virtual switch selected."
                            write-warning "$VMSwitch`n" 
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

write-host "                                Operating System ISO                                 "`n -ForegroundColor White -BackgroundColor Black  
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
        
        new-vm -Name $VMName -Path $VMPath"\" -Generation 2 -VHDPath $vhdPath -BootDevice VHD -MemoryStartupBytes $RAMAssigned   
    
        # Putting VM on network switch?
        If ($VMSwitch -ne "No virtual switch selected."){
            Get-VM -VMName $VMname | Set-VMSwitch $VMSwitch}      
        
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
        New-VM -Name $VMname -Path $VMpath -Generation 2 -NewVHDSizeBytes 127GB -NewVHDPath "$HDPath\$vmname.vhdx" -MemoryStartupBytes $RAMAssigned
        
        # Putting VM on network switch?
        If ($VMSwitch -ne "No virtual switch selected."){
            Get-VM -VMName $VMname | Set-VMSwitch $VMSwitch}      
        # Adding an ISO to the VM?
        If ($ISO -ne "No .ISO selected."){
            Add-VMDvdDrive -VMName $VMname -Path $ISO
            $bootorder = (Get-VMFirmware -VMName $vmname).bootorder | Sort-Object -Property Device
            Get-VM -VMName $VMname | Set-VMFirmware -BootOrder $bootorder}
        Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
        Enable-VMTPM -VMName $VMName
        Set-VM -Name $VMName -ProcessorCount 4 -SmartPagingFilePath $HDPath -AutomaticStartAction StartIfRunning -DynamicMemory 

        # Add VM SN# to Hyper-V VM notes to make it easier to find for Autopilot maintenance.
        Get-WmiObject -ComputerName . -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData `
         | ? { $_.VirtualSystemType -eq ‘Microsoft:Hyper-V:System:Realized’} | select elementname, BIOSSerialNumber `
         | Sort elementName | % { Set-VM -ComputerName . -Name $VMname -Notes $_.BIOSSerialNumber }
                 
        }        
        write-host -ForegroundColor Cyan "Created $vmname!"
        Start-VM $VMname
        start-sleep 1
    }
    
    write-host -ForegroundColor Green "`n`nComplete!`n"

#endregion ********************************************************************************************
    
exit
