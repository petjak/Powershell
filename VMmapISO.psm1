<#
.SYNOPSIS
Map an ISO File to VM
 
.DESCRIPTION
Map an ISO File to VM
 
.NOTES
File Name : VMmapISO.psm1
Author : Peter Jasenak in cooperation with Nadine Zander
Requires : PowerShell V3, PowerCLI 6.0

needs to be ran on administrative server to be able to run CLI commands
Set-PowerCLIConfiguration -DisplayDeprecationWarnings $false -Confirm:$false 
 
#>
$global:VM
Function Get-VMmapISO {
Param(
$VM,
[validateSet("Map", "Unmap")]$actiontype,
[validateSet('2017', '2016', '2014', '2012')]$selectedversion,
$cred)

if (!($cred))
{
[string]$login = $env:USERDOMAIN +"\"+ $env:USERNAME
$cred = Get-Credential -UserName $login -Message "Enter valid credentials"
}
$lastupdate = (Get-item -Path \\kmladm22\e$\list_of_iso.xml).LastWriteTime
$vcenter = "kmlvmc01.bs.kme.intern"




Clear-Host
if(!($VM)) {$VM = read-host -Prompt 'Type the VM name'}
if(!($actiontype)){
DO {
    clear-host
    $actiontype = Read-Host -Prompt 'What do you want to do? Type Map/Unmap'
    } until ($actiontype -match "[map][unmap]")
}
    switch ($actiontype) {
    "map" { if (!$selectedversion) {
                Clear-Host
                $version='2017', '2016', '2014', '2012' #list of available versions of SQL server
                Write-Host "Select SQL server version:"
                Write-Host "--------------------------"
                $menu1=@{}
                for ($i=1;$i -le $version.count; $i++) 
                { Write-Host "$i. $($version[$i-1])" 
                $menu1.Add($i,($version[$i-1]))}
                Write-Host ""
                [int]$selection = Read-Host -Prompt 'Enter the number>'
                $selectedversion = $menu1.Item($selection)
            }

        DO {
            Clear-Host 
            $update = Read-Host -Prompt "The list of ISO was updated $lastupdate last time. Do you want to update the list of available ISOs (Can take some time)? Y/N"
           } until ($update -match "^[yYnN]$")
        Switch ($update) {
            "y" {
                Write-Host "Getting the info from vCenter and updating the file"
 
                # Connect vCenter
                Connect-VIServer -Server $vcenter -Credential $cred -WarningAction SilentlyContinue
                $IsoOnDatastore = get-item -Path vmstores:\kmlvmc01.bs.kme.intern@443\01_BEU\01_BEU_Hannover\ISO\isos\02_MS_SQL_Server\* | Export-Clixml \\kmladm22\e$\list_of_iso.xml
                $listofiso = Import-Clixml \\kmladm22\e$\list_of_iso.xml | Where {$_.Name -like "*$selectedversion*"} | Select @{name="path";E={$_.DatastoreFullPath}}

                }
            "n" {
                $listofiso = Import-Clixml \\kmladm22\e$\list_of_iso.xml | Where {$_.Name -like "*$selectedversion*"} | Select @{name="path";E={$_.DatastoreFullPath}}
                }
            }  
            
        Clear-Host
        Write-Host "Select ISO:"
        Write-Host "-----------"
        $menu2=@{}
        for ($i=1;$i -le $listofiso.count; $i++) 
        { Write-Host "$i. $($listofiso[$i-1].path)" 
        $menu2.Add($i,($listofiso[$i-1].path))}
        Write-Host ""
        [int]$selection2 = Read-Host -Prompt 'Enter the number>'
        [string]$selectedISO = $menu2.Item($selection2)
        $ISO = $selectedISO
        Clear-Host
        Write-Host "Mapping..."

            # Connect vCenter
            Connect-VIServer -Server $vcenter -Credential $cred -WarningAction SilentlyContinue

            Get-VM -name $VM | Get-CDDrive | Set-CDDrive -IsoPath $ISO  -StartConnected:$true -Connected:$true -Confirm:$false

    }
    "unmap" {
        Clear-host
        Write-Host "Unmaping..."
 
            # Connect vCenter
            Connect-VIServer -Server $vcenter -Credential $cred
            Get-VM kmladm22 | ` Get-CDDrive | ` Set-CDDrive -NoMedia ` -Confirm:$false 

            }
    }

Disconnect-VIServer -Server $vcenter -Confirm:$false
}
Export-ModuleMember -Function 'Get-VMmapISO'