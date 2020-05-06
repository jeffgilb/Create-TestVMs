
<#PSScriptInfo

.VERSION 1.3

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
 
.DESCRIPTION 
 Script to automate the creation of test Hyper-V VMs. 
#>

#################################### DEFAULT PARAMETERS #######################################

# Edit these to set defaults for the script to use:

param(
    [Parameter(Mandatory=$False)] [String] $VMPath = "C:\ProgramData\Microsoft\Windows\Hyper-V\",
    [Parameter(Mandatory=$False)] [String] $HDPath = "C:\Users\Public\Documents\Hyper-V\Virtual Hard Disks\",
	[Parameter(Mandatory=$False)] [Int] $RAM = 2, # 2GB = 2*1073741824
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

############################## VIRTUAL MACHINE STORAGE LOCATIONS ##############################

CLS 
write-host -ForegroundColor White -BackgroundColor Black `n"                                                                              " 
write-host -ForegroundColor White -BackgroundColor Black "                      Virtual Machine Storage Locations                       " 
write-host -ForegroundColor White -BackgroundColor Black "                                                                              `n" 
write-host "By default, your Hyper-V VMs will be stored in the following locations:`n"  
write-host "VirtualMachinePath  : "$VMPath "`n"
write-host "VirtualHardDiskPath : "$HDPath "`n"

###### Virtual Machine Config Files Path #####

Write-host "Do you need to change the Virtual Machine Path?" -ForegroundColor Yellow 
$Readhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($ReadHost) 
     { 
      Y {
        $folder = Get-Folder
        If ($folder){$VMPath = $folder}
        write-host -ForegroundColor Green "Virtual Machine path will be: $VMPath.`n"
        } 
      N {}  
   }
   if ($readhost -ne "y"){write-host -ForegroundColor Green "`n Default selected.`n"}

##### Virtual Machine Hard Disk Path #####

Write-host "Do you need to change the Virtual Machine Hard Disk Path?" -ForegroundColor Yellow 
$Readhost = Read-Host " [Y] [N] (Default is N)"  
    Switch ($ReadHost) 
     { 
      Y {
        $folder = Get-Folder
        If ($folder){$HDPath = $folder}
        write-host -ForegroundColor Green "Virtual Machine hard disk path will be: $HDPath.`n"
        } 
      N {}  
   }
   if ($readhost -ne "y"){write-host -ForegroundColor Green "`n Default selected.`n"}

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
        If ($file){$ISO = $file;write-host -ForegroundColor Green `n"This ISO will be mounted: $ISO.`n"}
        Else {Write-Warning "Browse cancelled by user. No .ISO will be mounted.";  $ISO = "No .ISO selected."}	
        }
       N {}  
     } 
     If ($readhost -ne "y"){
                            $ISO = "No .ISO selected."
                            write-host "`n"
                            write-warning "No .ISO will be mounted!`n" 
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
write-host -ForegroundColor Cyan "VMs will have this much RAM:    "$RAM"GB"
write-host -ForegroundColor Cyan "Network switch to use:          "$VMSwitch
write-host -ForegroundColor Cyan "This .ISO will be mounted:      "$ISO
write-host -ForegroundColor Cyan "VM names will start with:       "$VMPrefix
write-host -ForegroundColor Cyan "Number of VMs to create:        "$VMnumber

Write-host -ForeGroundColor Cyan "`n`nTo modify the default values used by the script, edit the default parameter`nsettings at the top of the script. If you installed the script using the `nInstall-Script Create-TestVMs PowerShell command, the script can be found at `n$env:ProgramFiles\WindowsPowerShell\Scripts.`n"

Write-Host -ForegroundColor Yellow "Press enter to begin creating VMs."
pause

######################################## CREATE VMs ###########################################

for ($i=1; $i -le $VMnumber; $i++)
{
    $VMSuffix = get-random -minimum 100 -maximum 999
    $VMname = $VMPrefix + "-" + $VMSuffix
    New-VM -Name $VMname -Path $VMpath -SwitchName $VMSwitch -Generation 2 -NewVHDPath "$HDPath\$vmname.vhdx" -NewVHDSizeBytes 127GB -MemoryStartupBytes $RAMAssigned
    If ($ISO -ne "No .ISO selected."){Add-VMDvdDrive -VMName $VMname -Path $ISO}
    $bootorder = (Get-VMFirmware -VMName $vmname).bootorder | Sort-Object -Property Device
    Get-VM -VMName $VMname | Set-VMFirmware -BootOrder $bootorder
    Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
    Enable-VMTPM -VMName $VMName
    Set-VM -Name $VMName -ProcessorCount 4 -SmartPagingFilePath $HDPath -AutomaticStartAction StartIfRunning -DynamicMemory 
    Start-VM $VMname
    # Add VM SN# to Hyper-V VM notes to make it easier to find for Autopilot maintenance.
    Get-WmiObject -ComputerName . -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData `
     | ? { $_.VirtualSystemType -eq ‘Microsoft:Hyper-V:System:Realized’} | select elementname, BIOSSerialNumber `
     | Sort elementName | % { Set-VM -ComputerName . -Name $VMname -Notes $_.BIOSSerialNumber }
    write-host -ForegroundColor Cyan "Created $vmname!"
    write-host "Added SN# to Hyper-V VM Setting notes.`n"
    }

write-host -ForegroundColor Green "Complete!`n"
write-host -ForegroundColor Cyan "`VM creation summary:`n"

exit
