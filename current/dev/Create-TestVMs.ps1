
<#PSScriptInfo

.VERSION 2.0

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
Version 2.0: Added capability to accept or change Hyper-V host save locations. Added version to PowerShell console title. Added differencing disk support and an OOBE snapshot while turned off.
 
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

############################## FOLDER AND FILE BROWSER FUNCTIONS ##############################

Function Get-Folder 
{
    write-host -ForegroundColor Red -BackgroundColor Yellow  `n"    * * * Dialog box may be hidden behind this, or another, window! * * *     "`n 
    $folder = ""
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"
    $foldername.SelectedPath = $initialDirectory
    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return $folder
}    

Function Get-File
{
    write-host -ForegroundColor Red -BackgroundColor Yellow  "    * * * Dialog box may be hidden behind this, or another, window! * * *     " 
    $file = ""
    Add-Type -AssemblyName System.Windows.Forms
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect = $false # Multiple files can be chosen
	    Filter = 'ISO Files (*.ISO)|*.ISO' # Specified file types
        }
    [void]$fileBrowser.ShowDialog()
    $file = $fileBrowser.FileName;
    return $file
}

Function Get-VHDX
{
    write-host -ForegroundColor Red -BackgroundColor Yellow  "`n    * * * Dialog box may be hidden behind this, or another, window! * * *     `n" 
    $vhdx = ""
    Add-Type -AssemblyName System.Windows.Forms
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect = $false # Multiple files can be chosen
	    Filter = 'VHDX Files (*.VHDX)|*.VHDX' # Specified file types
        }
    [void]$fileBrowser.ShowDialog()
    $vhdx = $fileBrowser.FileName;
    return $vhdx
}

$Version = "Create-TestVMs v2.0"
$host.ui.RawUI.WindowTitle = $Version

############################## VIRTUAL MACHINE STORAGE LOCATIONS ##############################

CLS 
write-host -ForegroundColor White -BackgroundColor Black `n"                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                      Virtual Machine Storage Locations                       " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                              `n" 

$vmpath = ""
$vmpath = get-vmhost | Select-Object -Property VirtualMachinePath
$path = """?($vmpath)"""
$path = $path.trimStart("""?(@{VirtualMachinePath")
$path2 = $path.trimStart("=")
$path3 = $path2.trimend("\})""")
$vmpath = $path3

$hdpath = ""
$hdpath = get-vmhost | Select-Object -Property VirtualHardDiskPath 
$hdpath = """?($hdpath)"""
$hdpath = $hdpath.trimStart("""?(@{VirtualHardDiskPath")
$hdpath = $hdpath.trimStart("=")
$hdpath = $hdpath.trimend("\})""")

write-host "The Hyper-V host machine is set to store VMs at these default locations:`n" 
write-host -ForeGroundColor Green "`tVM configuration files:`t" $vmpath"`n`n`tVM hard disk files:`t $HDpath"`n""

write-host -ForeGroundColor Yellow "Do you want to use the default storage settings?"
$Readhost = Read-Host " [Y] [N] (Default is Y)"  
    Switch ($ReadHost){ 
        Y {} # Use default setting.
        N {    
           write-host -ForeGroundColor Yellow " Do you want to change the host defaults for where to store VMs?" 
           $VMReadhost = Read-Host " [Y] [N] (Default is N)"
           Switch ($VMReadhost){
             Y {
                $folder = Get-Folder
                If ($folder){$VMPath = $folder}
                write-host -ForegroundColor Green "Virtual Machine path will be: $VMPath.`n"
               }
             N {}
           }
        If ($VMReadhost -ne "y"){write-host -ForegroundColor Green "`nDefault VM storage setting will be used.`n"}        
           write-host -ForeGroundColor Yellow "Do you want to change the host defaults for where to store VM hard disks?" 
           $HDReadhost = Read-Host " [Y] [N] (Default is N)"
           Switch ($HDReadhost){
             Y {
                $folder = Get-Folder
                If ($folder){$HDPath = $folder}
                write-host -ForegroundColor Green "Virtual Machine hard disk path will be: $HDPath.`n"
               }
             N {}
            }
        If ($HDReadhost -ne "y"){write-host -ForegroundColor Green "`nDefault VM hard disk storage setting will be used.`n"}     
      }
    }
       
    If ($ReadHost -ne "n"){write-host -ForeGroundColor Green "`nHyper-V host default settings will be used.`n"}
        Else{
             write-host "The Hyper-V host machine will be set to store VMs at these default locations:`n" 
             write-host -ForeGroundColor Green "`tVM configuration files:`t" $vmpath"`n`n`tVM hard disk files:`t $HDpath"`n""
            }


############################## HARD DISK CONFIGURATION ##############################
write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                           VM Hard Disk Options                               " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                             "`n 

# Prompt for master VHDX to use for differencing disks
write-host -ForeGroundColor Yellow "Do you have a sysprepped VHDX to use as a master for differencing disks?"
$VHDXReadhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($VHDXReadHost){ 
        Y { 
            write-host "Browse to and select your sysprepped .VHDX. This will be used as the master image for differencing disks."      
            $vhd = get-vhdx
            If ($vhd){
                $vhdx = $vhd;write-host -ForegroundColor Green `n"The VM will be set to boot from: $vhdx.`n"
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

###################################### RAM SETTINGS ###########################################

write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                         Amount of RAM For New VMs                            " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                              `n" 
write-host "The default amount of RAM to assign to VMs is" $RAM"GB.`nYour Hyper-V host currently has this much available RAM:"   
Get-WmiObject -Class win32_computersystem -ComputerName . | ft @{Name="TotalPhysicalMemory (GB)";e={[math]::truncate($_.TotalPhysicalMemory /1GB)}}  
write-host "Do you need to change the amount of RAM assigned to VMs?" -ForegroundColor Yellow 

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

##################################### NETWORK SWITCH ##########################################

write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                          Virtual Network Switch                              " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                              `n" 
write-host "The default switch to use is currently set to:" $VMSwitch
write-host `n"Do you need to change the virtual switch?" -ForegroundColor Yellow 
$Readhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($ReadHost) 
     { 
       Y {
         write-host -ForeGroundColor Yellow "`nThese virtual switches are available:"
         get-vmswitch | Format-list Name
         $VMSwitch = read-host "`nEnter the name of the virtual switch to use"
         write-host
         write-host -ForegroundColor Green "Virtual switch"$VMSwitch" will be used.`n"}     
       N {}  
    } 
    If ($readhost -ne "y"){write-host -ForegroundColor Green "`n Default selected.`n"}

######################################### ISO #################################################

write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                           Operating System ISO                               " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
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

#################################### NAMING PREFIX ############################################

write-host "`n"
write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                       Virtual Machine Naming Prefix                          " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 

write-host "`nThe VM name prefix will be followed by -999 where 999 is three random numbers.`n"   -ForegroundColor Yellow

$Prefix = read-host "Enter a VM naming prefix (default is $VMPrefix)"
If ($Prefix -ne ""){$VMPrefix = $Prefix}
Write-host -ForegroundColor Green "`nVM names will start with $VMPrefix.`n"

############################### NUMBER OF VMs TO CREATE #######################################

write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                          Number of VMs to Create                             " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
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

######################################## SUMMARY ##############################################

write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                                   Summary                                    " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                              " 
write-host -ForegroundColor Cyan "`nVMs will be stored here:        "$VMPath  
write-host -ForegroundColor Cyan "Hard disks will be stored here: "$HDPath
If ($vhdx -ne ""){write-host -ForegroundColor Cyan "Differencing disks master at:   "$masterVHDX}  
write-host -ForegroundColor Cyan "VMs will have this much RAM:    "$RAM"GB"
write-host -ForegroundColor Cyan "Network switch to use:          "$VMSwitch
write-host -ForegroundColor Cyan "This .ISO will be mounted:      "$ISO
write-host -ForegroundColor Cyan "VM names will start with:       "$VMPrefix
write-host -ForegroundColor Cyan "Number of VMs to create:        "$VMnumber

Write-host -ForeGroundColor Cyan "`n`nTo modify the default values used by the script, edit the default parameter`nsettings at the top of the script. If you installed the script using the `nInstall-Script Create-TestVMs PowerShell command, the script can be found at `n$env:ProgramFiles\WindowsPowerShell\Scripts.`n"

pause

######################################## CREATE VMs ###########################################

# If alternate VM storage paths were provided, update them now:
Set-VMHost -VirtualMachinePath $vmpath
Set-VMHost -VirtualHardDiskPath $hdpath
            

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
        
        new-vm -Name $VMName -Path $VMPath"\" -SwitchName $VMSwitch -Generation 2 -VHDPath $vhdPath -BootDevice VHD -MemoryStartupBytes $RAMAssigned   #-NewVHDSizeBytes 127GB
    
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
Else{
    for ($i=1; $i -le $VMnumber; $i++)
        {
        $VMSuffix = get-random -minimum 100 -maximum 999
        $VMname = $VMPrefix + "-" + $VMSuffix
        New-VM -Name $VMname -Path $VMpath -SwitchName $VMSwitch -Generation 2 -NewVHDSizeBytes 127GB -NewVHDPath "$HDPath\$vmname.vhdx" -MemoryStartupBytes $RAMAssigned
    
    
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
    
exit
