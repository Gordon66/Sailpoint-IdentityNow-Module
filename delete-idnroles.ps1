Function delete-idnroles {
<#
   .SYNOPSIS
        Script was built to delete selected IDN roles

   .DESCRIPTION
        Script was built to delete a set of selected IDN roles. User defines name fiter upon which group of roles from specified IDN instance and source is selected. 
        Roles have to be removed from users before running the cleanup in IDN.  
        Connection to IDN Url. Local IDN account and API credentials. 
          
        Constrains:
        You have to load functions get-idnauthorisation and get-idnheaders before running the script 
        
        
    .INPUTS 
        Filter - name filtering parameter to select group of access profiles 
        IDN and API Credentials
        
    .OUTPUTS:
        Deletion of the selected group of roles in IDN. Exports succeeded deletions and failed deletions as xml file on your desktop. 
      
    .PARAMETER  Global:Filter
        has to contain desired name mask for access profile group selection 

            
    .EXAMPLE
        delete-idrole YourTenantOrg GRBTAC*

    .NOTES
        delete-IDNroles
        Version: 1.2
        Creator: Richard Sidor
        Date:    05-02-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        30-10-2018   1.0     RS       Initial version
        05-02-2019   1.2     RS       Authorisation part standardised with other scripts, correction of logging 
        
    .LINK
        https://api.identitynow.com/        
 #>

[CmdletBinding()]
Param([Parameter(mandatory=$true,valuefrompipeline=$true,Position=0)]
[string]$global:instance,
[Parameter(mandatory=$true,valuefrompipeline=$true,Position=1)]
[string]$global:filter 
)


$global:hds = $null
$global:pd = $null
[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

[string]$summarypath = "$env:USERPROFILE\Desktop\$global:Timestamp\"
[string]$summaryfile = "$($global:instance)-role-deletion-summary.txt"

IF (!(test-path $summarypath)){try{new-item -ItemType Directory -path $summarypath
cls
}
catch {write-output "Not able to create report folder on your desktop." }
}


get-IDNauthorisation $global:instance


if ($global:pd) {remove-Variable crd -Scope local}

DO {

[array]$failed = @()
[array]$succeeded = @()

[array]$get = @()
[array]$global:roles = @()
[array]$global:delroles = @()


[int]$page=0
[int]$limit=250

[array]$get = @()

DO { 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https://$global:instance.api`.identitynow.com/cc/api/role/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
$page +=249
[array]$global:roles += ($get.Content | Out-String | convertfrom-json)
[int]$perc = (($global:roles.Items).count/($global:roles | select count).count *100)
Write-Progress -Activity "Reading roles from IDN instance $($global:instance)" -Status "Percent complete...$perc`% of $(($global:roles | select count).count) records read" -PercentComplete $perc -Completed
} WHILE (($global:roles.Items).count -lt ($global:roles | select count).count)

$global:roles = $global:roles.items |sort displayname -Unique

if (!(test-path $summarypath$global:Timestamp-Roles-backup.xml)){ Export-Clixml -InputObject $global:roles -Path "$summarypath$global:Timestamp-Roles-backup.xml" -NoClobber}

"`r`n"*6
Write-output "The number of found roles in IDN: $($global:roles.count). Backup export done to file $($summarypath)$($global:Timestamp)-Roles-backup.xml" | Tee-object -FilePath  $summarypath$summaryfile -Append

if (!($global:filter)) {$global:filter = Read-Host "Please select filter (Role name mask) to select colletion of roles for deletion. (Mask characters avaliable:*)"}

if ($global:filter) {$global:delroles = $global:roles | select displayname,owner | ?{$_.Displayname -like "$global:filter"}}

if ($global:delroles) {
Write-output "The number of roles selected : $($global:delroles.count)" | Tee-object -FilePath  $summarypath$summaryfile -Append

$global:delroles

[string]$question = read-host "Proceed with deletion? y/n"
    while ($question -notmatch "[yYnN]{1}" -or $question.length -gt 1){
        if ($question -match "[nN]{1}" -and $question.length -eq 1) { 
        Write-output "Deletion aborted."
        Break}
        $question = read-host "Proceed with deletion? y/n"
    }

#deletion of connected roles 
if ($question -match "[yY]{1}" -and $question.length -eq 1){
[int]$counter=0

foreach ($dr in $global:delroles){
[int]$perc = (($Counter/$global:delroles.count) *100)
Write-Progress -Activity "Deleting roles from IDN instance $($global:instance) and source $($global:source)" -Status "Percent complete...$perc`% of $($global:delroles.count.tostring()) : Deleting $($dr.displayName)" -PercentComplete (($Counter/$global:delroles.count) *100) -Completed
 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https:`/`/$global:instance`.api`.identitynow`.com`/cc`/api`/role`/delete`/$($dr.id)"
[string]$post = $dr | ConvertTo-Json

$get = Invoke-WebRequest -Uri $url -body $post -ContentType 'application/json' -Headers $ent_Headers -Method POST  

if($get.statuscode -eq 200){$succeeded +=$dr}
elseif ($get.statuscode -ne 200) {$failed +=$dr}
$counter++
}

Write-output "The number of deleted roles : $($succeeded.count)" | Tee-object -FilePath  $summarypath$summaryfile -Append
Write-output "The number of failed role deletions : $($failed.count)" | Tee-object -FilePath  $summarypath$summaryfile -Append

$failed | Export-Clixml -Path "$summarypath$global:Timestamp-failed-role_deletions.xml"
$succeeded | Export-Clixml -Path "$summarypath$global:Timestamp-succeeded-role_deletions.xml"

}
}
if (!($global:delroles)) {
Write-output "No roles for deletion were selected." | Tee-object -FilePath  $summarypath$summaryfile -Append}

$global:filter = $null

$question0 = Read-host "Do you want to delete additional role(s)? y/n"
    while ($question0 -notmatch "[yYnN]{1}" -or $question0.length -ne 1){
        if ($question0 -match "[nN]{1}" -and $question0.length -eq 1) { 
        Write-output "Exiting ...."
        break}
        $question0 = Read-host "Do you want to delete additional role(s)? y/n"
            }

} UNTIL($question0 -match "[nN]{1}" -and $question0.length -eq 1)

Write-host "Script has ended. Summary and export files can be found in : $($summarypath)" -foreground green

Remove-Variable pd -Scope global
Remove-Variable hds -Scope global
Remove-Variable instance -Scope global
Remove-Variable Timestamp -Scope global
}