param (
    [Parameter(Mandatory=$true)][string]$runId,
    [string]$TFE_TOKEN
)

<#
 .SYNOPSIS
 Connects to Terraform Cloud and......
 
./ps-showPolicyCheck.ps1 -TFE_TOKEN emLjbISe41BIkA.atlasv1.rzjSLXjJRn7TfZ3yhOBrI4Hw7PzJmJb5xOD0h6792cBRQU9rnHFjz3lytH5R8dYgAnA -policyCheckId 


 .DESCRIPTION

 .PARAMETER TFE_TOKEN
 Temporary while we test. This should never be passed as a parameter in the command line. 
 Use Environment variables or preferably a dynamic credential created by a solution such as Hashicorp Vault.

 .PARAMETER runId

 .EXAMPLE 
 PS> ./pd-applyrun.ps1 -TFE_TOKEN $$blahBlahYourTerraformCloudAPIToken$$$ -organization "your-TF-Org" -workdspace "WorkspaceWhereRunCreated" -runId "IdOfTheRunToApply"

#>



# Check that the `TFE_TOKEN` environment variable is set.
if (Test-Path env:token) {
    write-host "TOKEN environment variable was found."
    }else {
        $env:token = $TFE_TOKEN
    }

# Evaluate $TFE_ADDR environment variable if it exists
# Otherwise, use "app.terraform.io"
if (Test-Path env:address) {
    write-host "Terraform Cloud address is $env:address"
}else {
    write-host "no Terraform Cloud address environment variable has been set. Using app.terraform.io"
    $env:address = "app.terraform.io"    
}


$headers = @{
    'Authorization' = "Bearer $env:token"
}

# List Policy Checks from specific Run
$uri = "https://$env:address/api/v2/runs/$runId/policy-checks"

$getRunResult = Invoke-RestMethod -uri $uri -headers $headers

$policyCheckId = $getRunResult.data.id
$policyCheckId

# Get Policy Checks
$uri = "https://$env:address/api/v2/policy-checks/$policyCheckId"

$getRunResult = Invoke-RestMethod -uri $uri -headers $headers

$getRunResult | ConvertTo-Json -Depth 20 | Out-File ./$policyCheckId.json

