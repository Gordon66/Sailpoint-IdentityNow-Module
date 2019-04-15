Function get-IDNheaders {
<#
   .SYNOPSIS
        Script was built to generate needed varialbles for OAUTH Token generation 

   .DESCRIPTION
        Script was built to generate needed varialbles for OAUTH Token generation 

        Dependencies: 
        
        
        Constrains:
        
        
    .INPUTS 
        Instance = IDN (Tenant) Organisation
        
        
    .OUTPUTS:
        Creates Headers with a generated OUATH Token for authorization on aPAI calls 
    
        
    .PARAMETER  Global:Instance
        should contain the desired IDN target instance (tenant)
                        
    .EXAMPLE
        get-IDNheaders "ACME" 

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

[string]$ent_url="https:`/`/$global:instance.identitynow.com`/api`/oauth`/token"
$gett = Invoke-WebRequest -Uri $ent_url -Body $global:payld -Headers $global:heads -Method POST
[string]$t = $($gett.Content | Out-String | ConvertFrom-Json).access_token
$Headers = @{Authorization = 'Bearer '+ $t}
return $Headers
}