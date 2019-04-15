Function get-IDNSources {
<#
   .SYNOPSIS
        Script was built to export and backup configuration files for sources in an IDN Instance

   .DESCRIPTION
        Script was built to export configuration Json and XML files from IDN Sources for backup purposes. 
        The script will get a list of sources and downloads the configuration files to folder C:\temp\sources\$($global:instance)-Sources. 
        
        Dependencies: 
        Connection to IDN Url. Local IDN account and API credentilas. 
          
        Constrains:
        You have to load functions get-idnauthorisation and get-idnheaders before running the script 
        
    .INPUTS 
        Instance - tenant organisation - name of the IDN instance YourTenantOrg set as default in case you will not provide any 
        IDN user and API user Credentials
        
    .OUTPUTS:
        List of the IDN Sources and their configuration files (JSON,XML) in folder C:\temp\sources\$($global:instance)-Sources-$Timestamp\

              
    .PARAMETER  Global:Instance
        has to contain desired IDN instance (YourTenantOrgn)

        
    .EXAMPLE
        get-idnsources YourTenantOrg

    .NOTES
        delete-IDNData
        Version: 1.2
        Creator: Richard Sidor
        Date:    21-1-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        13-11-2018 1.0      RS        Initial version
        21-1-2019  1.2      RS        Added error handling
    
    .LINK
        https://api.identitynow.com/        
 #>

[CmdletBinding()]
Param([Parameter(mandatory=$false,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg" )

[string]$Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')
[string]$summarypath = "C:\temp\sources\$($global:instance)-Sources-$Timestamp\"
[string]$summaryfile = "$($global:instance)-Export_summary.txt"

if (!(test-path -path $summarypath)) {new-item -ItemType Directory -path $summarypath | Out-Null}

[array]$get = @()
[array]$global:sources = @()
[array]$global:source = @()

$global:hds = $null
$global:pd = $null
[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

get-IDNauthorisation $global:instance

#Query for list of configured AD sources 
$counter = 0

[int]$page=0
[int]$limit=250
[array]$get = @()

DO { 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https://$global:instance.api`.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"

$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 

$page +=249

$source = $get.Content | Out-String | convertfrom-json

[array]$global:sources += $source

[int]$perc = ($global:sources.count / $get.Headers.'X-Total-Count') *100

Write-Progress -Activity "Exporting sources from IDN instance $($global:instance): $($source.name) - ID $($sourcename.id)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources exported" -PercentComplete $($perc)

} WHILE ($global:sources.count -lt $get.Headers.'X-Total-Count')


Write-Host "Number of found IDN sources: $($Global:sources.count)" | tee-object -FilePath $summarypath$summaryfile -Append
$Global:sources | export-csv -path $summarypath$($global:instance)-Sources-$Timestamp.csv -Delimiter ";" -NoTypeInformation

$global:sources | select name,id,owner,sourceConnectorName,sourcetype | ft -wrap | tee-object -FilePath $summarypath$summaryfile -Append

$question0 = Read-host "Do you want to export a single source? y/n"

while ($question0 -notmatch "[yYnN]{1}"){

if ($question0 -match "[nN]{1}") { 
Write-output "Proceeding with export of all sources."| tee-object -FilePath $summarypath$summaryfile -Append
Continue}
$question0 = Read-host "Do you want to export a single source? y/n"
}

if ($question0 -match "[yY]{1}") { 
$global:sources = $global:sources | out-gridview -PassThru -Title "Please select a desired source for export. "
Write-output "Proceeding with export of a single source: $($global:countries) "| tee-object -FilePath $summarypath$summaryfile -Append
}

if ($Global:sources) {
Write-output "Source(s) selected for export:"| tee-object -FilePath $summarypath$summaryfile -Append
$global:sources | select name,id,owner,sourceConnectorName,sourcetype | ft -wrap | tee-object -FilePath $summarypath$summaryfile -Append


foreach ($id in $global:sources.id) {

$ent_Headers = get-IDNheaders $global:instance

[string]$url = "https://$($global:instance).identitynow.com/api/source/get/$($id)"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET -OutFile $summarypath$($id).json


    if ($?) {write-host "JSON Configuration of the source $($id) exported fine." | tee-object -FilePath $summarypath$summaryfile -Append }
    elseif ($? -eq $false) {write-host "There was a problem with JSON export of the sources confiration: $($id)." | tee-object -FilePath $summarypath$summaryfile -Append}         
    
[string]$url = "https://$($global:instance).identitynow.com/cc/api/source/export/$($id)"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET -OutFile $summarypath$($id).xml

    if ($?) {write-host "XML Configuration of the source $($id) exported fine." | tee-object -FilePath $summarypath$summaryfile -Append} 
    elseif ($? -eq $false) {write-host "There was a problem with XML export of the sources confiration: $($id)." | tee-object -FilePath $summarypath$summaryfile -Append}
               
    }
 }
Remove-Variable pd -Scope global
Remove-Variable hds -Scope global
}