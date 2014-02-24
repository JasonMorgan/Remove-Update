Function Remove-Update
{
<#
.SYNOPSIS
Remove updates accessible in the Win32_quickfixEngineering class

.DESCRIPTION
This Function will work, remotely or locally, to remove specified updates.  Updates are removed using the WUSA.exe utility.  
All updates targetted by this function must be accessible via the Win32_quickfixEngineering WMI class, if you need to 
remove an MSI based update this tool will not work.  Also it relies heavily on PSRemoting, if PSRemoting is not enabled in 
your environment please escalate the issue with your System Administrator.

.EXAMPLE
Remove-update -computername $computers -articleID KB1234567 

Removes the KB1234567 update from all computers in the $Computers variable

.EXAMPLE
Get-content .\computers.txt | Reomve-Update -articleID (get-content .\Badpatches.txt)

Removes all the updates stored in the BadPatches.txt file from all the computers listed in .\Computers.txt.

.EXAMPLE
$Patches = Get-Hotfix -computername Computer1 | where {$_.installedon -ge (get-date).adddays(-30)} | select -expandproperty HotfixID

Remove-Update -computername Computer1 -articleID $patches

First gather all patches that have been installed in the last 30 days using Get-Hotfix, then remove them with Remove Update.

.NOTES
Written by Jason Morgan
Created on 2/23/2014
LastModified 2/23/2014
Version 1.0.0.3

#Added help and made $articleID Mandatory
#Removed Param block and switched to $args

#>
[CmdletBinding(ConfirmImpact='Medium')]
param (
      # Enter a computername or multiple computernames
      [Parameter(
      Mandatory, 
      ValueFromPipeline=$True, 
      ValueFromPipelineByPropertyName=$True,
      HelpMessage="Enter a ComputerName or IP Address, accepts multiple ComputerNames")]             
      [Alias("__Server")]
      [String[]]$ComputerName,

      # Enter target ArticleIDs to be removed, Valid article IDs start with KB and are then followed by a sequence of numbers, ex: KB1456926
      [Parameter(Mandatory)]
      [ValidateScript({$_.startswith('KB')})]
      [validatelength(5,12)]
      [string[]]$ArticleID,

      # Enter a Credential object, like (Get-credential)
      [Parameter(
      HelpMessage="Enter a Credential object, like (Get-credential)")]
      [System.Management.Automation.PSCredential]$credential
      )
Begin 
    {
        $Params = @{
                ArgumentList = $ArticleID
                Scriptblock = {
                        Try {$VerbosePreference = $Using:VerbosePreference} Catch {Write-Verbose "Sending Errors to the Void"}
                        Try {$DebugPreference = $Using:DebugPreference} Catch {Write-Verbose "Sending Errors to the Void"}
                        Write-Verbose "Gathering patches on $ENV:COMPUTERNAME"
                        $patches = Get-HotFix
                        Foreach ($p in $patches)
                          {
                            Write-Verbose "Testing patch against `$articleID"
                            If ($args -contains $p.HotfixID)
                              {
                                Write-Debug "Patch to be Removed: $($p.HotfixID)"
                                Start-Process wusa.exe -ArgumentList "/uninstall", "/KB:$($p.hotfixID.trimstart('KB'))", "/quiet", "/norestart" -Wait
                              }
                          }
                    }
            }
        If ($credential) {$Params.Add('Credential',$credential)}
    }
Process
    {
        [System.Collections.ArrayList]$comps += $ComputerName 
    }
End {
        if ($Comps -contains $ENV:COMPUTERNAME)
                {
                    $Comps.Remove("$ENV:COMPUTERNAME")
                    $local = $True
                }
            if (($Comps | measure).Count -gt 0)
                {
                    $params.Add('ComputerName',$Comps)
                    Invoke-Command @params
                }
            if ($local)
                {
                    Try {$params.Remove('ComputerName')} Catch {Write-Verbose "Sending Errors to the Void"}
                    Invoke-Command @params
                }   
    }
}