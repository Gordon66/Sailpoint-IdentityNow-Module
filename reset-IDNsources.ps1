Function reset-IDNsources{

<#
   .SYNOPSIS
        Script was built to reset IDN Source(s)

   .DESCRIPTION
        Script was built to reset IDN Source(s). You can enter one ID or array of IDs delimited by ","  

        Dependencies: 
                
        Constrains:
                
    .INPUTS 
        Instance = IDN Organisation
        Filter = Name mask filter for selection of IDN sources 
        IDN IDs = local IDN user credentials 
        IDN API credentials 
        
        
    .OUTPUTS:
        resets selectio of IDN Source(s) 
    
    .PARAMETER  Instance
        should contain the desired IDN target instance 
    .PARAMETER  Filter
        should define source name or mask or multiple sources 
                        
    .EXAMPLE
        reset-source 

    .NOTES
        Set-IDNData
        Version: 1.2
        Creator: Richard Sidor
        Date:    25-02-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        07-02-2019 1.0      RS        Initial version
        25-02-2019 1.2      RS        Added array of multiple sources as input 
        
    .LINK
        https://api.identitynow.com/        
 #>

Param([Parameter(mandatory=$false,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg", 
[Parameter(mandatory=$false,valuefrompipeline=$true,Position=1)]
[string[]]$Filter = "",
[Parameter(mandatory=$false,valuefrompipeline=$false)]
[switch]$Grid
)

[string]$summarypath = "$env:USERPROFILE\Desktop\$global:Timestamp\"
[string]$summaryfile = "reset-summary.txt"

[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')
IF (!(test-path $summarypath)){try{new-item -ItemType Directory -path $summarypath
cls
}
catch {write-output "Not able to reset report folder on your desktop." }
}


get-IDNauthorisation $global:instance

DO{
[array]$sources = @()
[array]$resetsources = @()
[array]$fail = @()
[array]$success = @()

[array]$get = @()

#Query for list of configured AD sources 
[int]$counter = 0

[int]$page=0
[int]$limit=250

[array]$get = @()

DO { 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https://$global:instance.api`.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
$page +=249

<#
[int]$perc = (($sources.count/$get.Headers.'X-Total-Count') *100)
Write-Progress -Activity "Reading sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources read" -PercentComplete $($perc)
#>

[array]$sources += $get.Content | Out-String | convertfrom-json


} WHILE ($sources.count -lt $get.Headers.'X-Total-Count')

Write-Host "Avaliable IDN sources for $($global:instance) are these $($sources.count):" | Tee-object -FilePath  $summarypath$summaryfile -Append
$sources = $sources | select id,name,description,owner,sourceConnectorName,sourceType,externalID |sort name -Unique | Tee-object -FilePath  $summarypath$summaryfile -Append
$sources | select id,name,description,owner,sourceConnectorName | ft -wrap

if ($grid) {$filter = ($sources | select id,name,description,owner,sourceConnectorName | Out-GridView -PassThru).id}

if ($filter) {$filter = $($filter) -split ","}
elseif (!($filter)) {[string[]]$filter = [string]$(Read-Host "Please select ID(s) of source(s) to reset") -split ","}

Foreach ($f in $filter) {
$f = $($f -replace ' ','')
if ($f -match "^[0-9]+${6}" ){
$resetsources += $sources | ?{$_.id -like "$f"} }
}

Write-Host "Selected sources for reset are: " | Tee-object -FilePath  $summarypath$summaryfile -Append
$resetsources | ft -wrap >>$summarypath$summaryfile 
$resetsources | select id,name,description,owner.name,sourceConnectorName | ft -wrap

if ($resetsources){
    [string]$question = read-host "Proceed with reset of these sources? y/n"
    while ($question -notmatch "[yYnN]{1}"){
    if ($question -match "[nN]{1}") { 
    Write-output "Reset aborted."
    Break}
    $question = read-host "Proceed with reset? y/n"
    }

if ($question -match "[yY]{1}") {

$ent_Headers = get-IDNheaders $global:instance

[int]$counter = 0

    foreach ($i in $resetsources){
    $counter++
    [int]$perc = ($counter/ [int]$resetsources.count) *100
    Write-Progress -Activity "Reseting sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($resetsources.count) sources reset" -PercentComplete $($perc)

    Write-host "Reseting source $($i.name) - $($i.id)"
    [string]$url = "https://$($global:instance).identitynow.com/api/source/reset/$($i.id)" | Tee-object -FilePath  $summarypath$summaryfile -Append
    $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST -ea Stop    
    Write-host "Waiting for reset to finish ..."
    sleep -Seconds 150

    switch ($send.StatusCode){
    200 {Write-host "Source with ID $($i.id) was succesfully reset" | Tee-object -FilePath  $summarypath$summaryfile -Append}
    default {Write-host "Error resetting source with ID $($i.id)" | Tee-object -FilePath  $summarypath$summaryfile -Append}
          }
    
        }
    }
}
$filter = $null

$question0 = Read-host "Do you want to reset another source? y/n"
    while ($question0 -notmatch "[yYnN]{1}"){
        if ($question0 -match "[nN]{1}") { 
        Write-output "Exiting ...."
        break}
        $question0 = Read-host "Do you want to reset another source? y/n"
            }

}UNTIL($question0 -match "[nN]{1}")

Remove-Variable pd -Scope global
Remove-Variable hds -Scope global
}