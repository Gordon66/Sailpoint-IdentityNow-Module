Function get-IDNauthorisation {
<#
   .SYNOPSIS
        Script was built to generate needed varialbles for OAUTH Token generation 

   .DESCRIPTION
        Script was built to generate needed varialbles for OAUTH Token generation 

        Dependencies: 
        IDN local user credentials, API credentials          
        
        Constrains:
        
        
    .INPUTS 
        Instance = IDN (Tenant) Organisation
        IDN local admin credentials
        IDN API credentials
        
    .OUTPUTS:
        Creates variables with global scope for headers and payload for OAUTH Token generation $global:payld  $global:heads
    
        
    .PARAMETER  Global:Instance
        should contain the desired IDN target instance (tenant)
                        
    .EXAMPLE
        get-IDNauthorisation "ACME" 

    .NOTES
        Set-IDNData
        Version: 1.0
        Creator: Richard Sidor
        Date:    18-2-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        18-2-2019   1.0      RS        Initial version

        
    .LINK
        https://api.identitynow.com/        
 #>
Param([Parameter(mandatory=$true,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg" )

$global:heads = $null
$global:payld = $null

#credential input 
$crd = Get-Credential -Message "Please provide you IDN username and password" 
if (!($crd)) {write-output "Please enter IDN credentials." 
break}
$acrd = Get-Credential -Message "Please provide you API IDN username and password"
if (!($acrd)) {write-output "Please enter API credentials." 
break}
[string]$at = "$($acrd.GetNetworkCredential().username)`:$($acrd.GetNetworkCredential().password)"
[string]$at =[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($at))
$global:heads = @{Authorization = "Basic $at"}

[array]$gett = @()

Function Get-StringHash([String]$String, [String]$HashName) { 
$StringBuilder = New-Object System.Text.StringBuilder 
[System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($string))|foreach{[Void]$StringBuilder.Append($_.ToString("x2"))} 
$StringBuilder.ToString()
}

if ($global:heads) { 
remove-Variable at -Scope local
remove-Variable acrd -Scope local

$global:payld = @{grant_type ='password'
username = $($crd.GetNetworkCredential().username) 
password = $(Get-StringHash "$($($crd.GetNetworkCredential().password.tostring())+$(Get-StringHash "$($crd.GetNetworkCredential().username.ToLower().tostring())" "SHA256"))" "SHA256")}

if ($global:payld) {remove-Variable crd -Scope local}
    }
}