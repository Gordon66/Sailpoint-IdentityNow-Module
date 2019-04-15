Function delete-IDNsources{
<#
   .SYNOPSIS
        Script was built to delete IDN Source(s)

   .DESCRIPTION
        Script was built to delete set of selected (by name mask) IDN Source(s) and reset them in case if the deletion does not proceed succesfully. 

        Dependencies: 
          Connection to IDN Url. Local IDN account and API credentilas.       
        
        Constrains:
          You have to load functions get-idnauthorisation and get-idnheaders before running the script 

                
    .INPUTS 
        Filter = Name mask filter for selection of IDN sources, mask character *
               
    .OUTPUTS:
        Deletes a selection of IDN Source(s) and created summary txt file in folder on your desktop  
    
    .PARAMETER  Instance
        should contain the desired IDN (tenant) instance 

    .PARAMETER  Filter
        should define source name or mask or multiple sources 
                        
    .EXAMPLE
        delete-IDNsources yourtenant mask*

    .NOTES
        delete-IDNsources
        Version: 1.2
        Creator: Richard Sidor
        Date:    20-03-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        31-01-2019 1.0      RS        Initial version
        20-03-2019 1.2      RS        Improved user interaction part 
        
    .LINK
        https://api.identitynow.com/        
 #>

Param([Parameter(mandatory=$false,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg", 
[Parameter(mandatory=$false,valuefrompipeline=$true,Position=1)]
[string]$Filter = $null
)

[array]$fail = @()
[array]$success = @()
[array]$get = @()
[array]$sources = @()
[array]$delsources = @()

$global:hds = $null
$global:pd = $null

[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

[string]$summarypath = "$env:USERPROFILE\Desktop\$global:Timestamp\"
[string]$summaryfile = "delete-summary.txt"

IF (!(test-path $summarypath)){try{new-item -ItemType Directory -path $summarypath
cls
}
catch {write-output "Not able to create report folder on your desktop." }
}

get-IDNauthorisation $global:instance

#Query for list of configured AD sources 
[int]$page=0
[int]$limit=250

[array]$get = @()

$ent_Headers = get-IDNheaders

DO { 
[string]$url ="https://$global:instance.api.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
$page +=249
[array]$sources += $get.Content | Out-String | convertfrom-json

<#
[int]$perc = (($sources.count/$get.Headers.'X-Total-Count') *100)
Write-Progress -Activity "Reading sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources read" -PercentComplete $($perc)
#>

} WHILE ($sources.count -lt $get.Headers.'X-Total-Count')

$sources = $sources | select id,name,description,owner,sourceConnectorName,sourceType |sort name -Unique

if ($sources){
DO{

Write-Host "Avaliable IDN sources for $($global:instance) are these $($sources.count):" | Tee-object -FilePath  $summarypath$summaryfile -Append
$sources | ft -Wrap | Tee-object -FilePath  $summarypath$summaryfile -Append


if (!($filter)) {$filter = Read-Host "Please select filter to select colletion of sources for deletion"}

$delsources = $sources | ?{$_.Name -like "$($filter)"} 

if ($delsources){

[boolean]$reset =$false

    Write-Host "Selected sources are:" | Tee-object -FilePath  $summarypath$summaryfile -Append
    $delsources | ft -wrap | Tee-object -FilePath  $summarypath$summaryfile -Append
    [string]$question = read-host "Do You want to proceed with deletion of the selected sources? y/n"
    while ($question.length -ne 1 -or $question -notmatch "[yYnN]{1}"){
    if ($question.length -eq 1 -and $question -match "[nN]{1}") { 
    Write-output "Deletion aborted."
    Break}
    $question = read-host "Do You want to proceed with deletion of the selected sources? y/n"
    }

if ($question.length -eq 1 -and $question -match "[yY]{1}") {
[int]$counter = 0

foreach ($id in $delsources){
$counter++
[int]$perc = ($counter/ $delsources.count) *100
Write-Progress -Activity "Deleting sources from IDN instance $($global:instance) - deleting source: $($id.id) - $($id.name)" -Status "Percent complete...$($perc)`% of $($delsources.count) sources deleted" -PercentComplete $($perc)


    try {$ent_Headers = get-IDNheaders
    Write-host "Deleting source: $($id.id) - $($id.name)." | Tee-object -FilePath  $summarypath$summaryfile -Append
    [string]$url = "https://$($global:instance).identitynow.com/api/source/delete/$($id.id)"
    $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST  
    start-Sleep -seconds 180
          }

    catch {
    $ent_Headers = get-IDNheaders
    Write-host "There was an error deleting source: $($id.id) - $($id.name). Triggering reset of the source." | Tee-object -FilePath  $summarypath$summaryfile -Append
    [string]$url = "https://$($global:instance).identitynow.com/api/source/reset/$($id.id)"
    $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST  
    if ($send.StatusCode -eq 200) {
    [boolean]$reset = $true
    Write-host "Source reset succesfully initiated: $($id.id) - $($id.name)" | Tee-object -FilePath  $summarypath$summaryfile -Append
    start-Sleep -seconds 180
        }
    }

finally { 
    
    switch ($reset){
   $true {  Write-host "Waiting for source reset to finish and retrying the deletion: : $($id.id) - $($id.name)"             
            $ent_Headers = get-IDNheaders            
            Write-host "Retrying deletion of the source after it has been reset: $($id.id) - $($id.name)" 
                [string]$url = "https://$($global:instance).identitynow.com/api/source/delete/$($id.id)"
                $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST  
            start-sleep -seconds 180
    
    #Query for list of configured AD sources 
    $sources = @()
    [int]$page=0
    [int]$limit=250

    [array]$get = @()

    $ent_Headers = get-IDNheaders

    DO { 
    [string]$url ="https://$global:instance.api.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
    $get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
    $page +=249
    [array]$sources += $get.Content | Out-String | convertfrom-json

    <#
    [int]$perc = (($sources.count/$get.Headers.'X-Total-Count') *100)
    Write-Progress -Activity "Reading sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources read" -PercentComplete $($perc)
    #>

    } WHILE ($sources.count -lt $get.Headers.'X-Total-Count')

    $sources = $sources | select id,name,description,owner,sourceConnectorName,sourceType |sort name -Unique

    if ($id.id -notin $sources.id) {Write-host "Source was succesfully deleted: $($id.id) - $($id.name)" }  
    elseif ($id.id -in $sources.id){Write-host "Source is still avaliable. Please check manually: $($id.id) - $($id.name)"  
                
        }
    }
   $false {    
    #Query for list of configured AD sources 
    $sources = @()
    [int]$page=0
    [int]$limit=250

    [array]$get = @()

    $ent_Headers = get-IDNheaders

    DO { 
        [string]$url ="https://$global:instance.api.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
        $get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
        $page +=249
        [array]$sources += $get.Content | Out-String | convertfrom-json

        <#
        [int]$perc = (($sources.count/$get.Headers.'X-Total-Count') *100)
        Write-Progress -Activity "Reading sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources read" -PercentComplete $($perc)
        #>

    } WHILE ($sources.count -lt $get.Headers.'X-Total-Count')

    $sources = $sources | select id,name,description,owner,sourceConnectorName,sourceType |sort name -Unique

    if ($id.id -notin $sources.id) {Write-host "Source was succesfully deleted: $($id.id) - $($id.name)" }  
    elseif ($id.id -in $sources.id) {  

                Write-host "Source is still avaliable. Waiting for source reset to finish and retrying the deletion."  
                $sources | ?{$_.id -like "$($id.id)"} 
                start-sleep -seconds 180

                [string]$url = "https://$($global:instance).identitynow.com/api/source/delete/$($id.id)"
                $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST  

                if ($send.StatusCode -eq 200) {Write-host "Retriggered the deletion of the source: $($id.id) - $($id.name)" | Tee-object -FilePath  $summarypath$summaryfile -Append}
                }           
            } 
        } 

      }
    }    
  }
}

$filter = $null

$question0 = Read-host "Do you want to delete additional source(s)? y/n"
    while ($question0.length -ne 1 -or $question0 -notmatch "[yYnN]{1}"){
        if ([int]$question0.length -eq 1 -and $question0 -match "[nN]{1}") { Write-output "Exiting ...."
        break}

        $question0 = Read-host "Do you want to delete additional source(s)? y/n"
            }

} UNTIL([int]$question0.length -eq 1 -and $question0 -match "[nN]{1}")
}

Write-host "Script has ended. Summary and export files can be found in : $($summarypath)" -foreground green

if ($global:pd){Remove-Variable pd -Scope global}
if ($global:hds){Remove-Variable hds -Scope global}
if ($global:instance){Remove-Variable instance -Scope global}
if ($global:delsources){Remove-Variable delsources -Scope global}
if ($global:source){Remove-Variable source -Scope global}
if ($global:Timestamp){Remove-Variable Timestamp -Scope global}

}