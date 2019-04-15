Function get-IDNidprofiles {
<#
   .SYNOPSIS
        Script was built to get list of IDN identity profiles and export their configuration to files 
         
   .DESCRIPTION
        Script was built to get list of IDN identity profiles and export their configuration to files in folder on this path C:\temp\profiles\$($global:instance)-IDprofiles-$global:Timestamp

        Dependencies: 
        Connection to IDN Url. IDN account and API credentilas. Loaded functions get-IDNauthorisation and get-IDNheaders from our module. 
          
        Constrains:
        
        
    .INPUTS 
        Instance - name of the IDN instance YourTenantOrg set as default in case you will not provide any 
        IDN user and API user Credentials
        
    .OUTPUTS:
        List of the IDN identity profiles and their configuration files (JSON,XML) in folder defined in C:\temp\profiles\$($global:instance)-IDprofiles-$($global:Timestamp)\ and in a global variable $global:IDNidprofiles

              
    .PARAMETER  Global:Instance
        has to contain desired IDN instance (YourTenantOrgn)

        
    .EXAMPLE
        get-IDNidprofiles YourTenantOrg

    .NOTES
        delete-IDNData
        Version: 1.0
        Creator: Richard Sidor
        Date:    11-2-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        11-2-2019  1.0      RS        Initial version
    
    .LINK
        https://api.identitynow.com/        
 #>

[CmdletBinding()]
Param([Parameter(mandatory=$false,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg" )

[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

[array]$get = @()
[array]$global:IDNidprofiles = @()
$result = @()

[string]$summarypath = "C:\temp\profiles\$($global:instance)-IDprofiles-$($global:Timestamp)\"
[string]$summaryfile = "Export_summary.txt"

if (!(test-path -path $summarypath)) {new-item -ItemType Directory -path $summarypath | Out-Null
cls}


get-IDNauthorisation $global:instance
 

#Query for list of configured AD profiles 
$counter = 0
try{
[array]$get = @()
$ent_Headers = get-IDNheaders
 Write-Host "Getting list of identity profiles from tenant organisation: $($global:instance)" | tee-object -FilePath $summarypath$summaryfile -Append

[string]$url ="https://$global:instance.api`.identitynow.com/cc/api/profile/list"

$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 

[array]$global:IDNidprofiles = $get.Content | Out-String | convertfrom-json}

catch {Write-Host "Could not retrieve IDN profiles from: $($url)" | tee-object -FilePath $summarypath$summaryfile -Append}

if ($global:IDNidprofiles){
Write-Host "Total number of found IDN profiles: $($global:IDNidprofiles.count)" | tee-object -FilePath $summarypath$summaryfile -Append
$global:IDNidprofiles | export-csv -path $summarypath$($global:instance)-IDprofiles-$global:Timestamp.csv -Delimiter ";" -NoTypeInformation
$global:IDNidprofiles | select id,name,description,identityCount,source | ft -wrap | tee-object -FilePath $summarypath$summaryfile -Append

$ent_Headers = get-IDNheaders

    foreach ($prof in $global:IDNidprofiles){
        
        Write-Host "Exporting identity profile: $($prof.id) - $($prof.name)" | tee-object -FilePath $summarypath$summaryfile -Append

        [string]$url ="https://$global:instance.api`.identitynow.com/cc/api/profile/get/$($prof.id)"
        $get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET -ea Stop 2>&1 >> $summarypath$summaryfile 
        $get.Content > $summarypath$($prof.id).json
        }
     }
if (!($global:IDNidprofiles)){Write-Host "No IDN profiles found in this IDN instance (tenant)!" | tee-object -FilePath $summarypath$summaryfile -Append
break}
Write-host "Export has ended. Summary and export files can be found in : $($summarypath)" -foreground green

Remove-Variable pd -Scope global
Remove-Variable hds -Scope global
Remove-Variable instance -Scope global
Remove-Variable Timestamp -Scope global

}