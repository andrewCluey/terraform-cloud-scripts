param (
    [Parameter(Mandatory=$true)][string]$workspace,
    [Parameter(Mandatory=$true)][string]$runId,
    [string]$TFE_TOKEN,
    [string]$organization,
    [string]$comment #Set a default value
)

<#
 .SYNOPSIS
 Connects to Terraform cloud and discards the run specified in `runId`.
 

 .DESCRIPTION
 Discards the Run specified in the input parameters.

 .PARAMETER workspace
 Required: Specifies the Worksp[ace to use or create.

 .PARAMETER runId
 Required: The Run ID that you wish to apply. 

 .PARAMETER organization
 Optional: Will first check local environment variables for $env:organization.
 If no env variable set, then this paramater is required.
 Specifies which Terraform Cloud Organization to create the new Workspace in.

#>


# Check that the `TFE_TOKEN` environment variable is set.
if (Test-Path env:token) {
    write-host "TOKEN environment variable was found."
    }else {
        $env:token = $TFE_TOKEN
    }

# Evaluate $TFE_ORG environment variable
# If not set, give error and exit
if (Test-Path env:organization) {
    write-host "Terraform Cloud Organization is $env:organization"
    write-host "Using organization $env:organization"
}else {
    $env:organization = $organization
}

# Evaluate $TFE_ADDR environment variable if it exists
# Otherwise, use "app.terraform.io"
if (Test-Path env:address) {
    write-host "Terraform Cloud address is $env:address"
}else {
    write-host "no Terraform Cloud address environment variable has been set. Using app.terraform.io"
    $env:address = "app.terraform.io"    
}

# Check for the Workspace input paramater. 
# If set configure as environment variable.
# If not, create error.
if ($workspace) {
    $env:workspace = $workspace
    write-host "The workspace to use is configured as $env:workspace"
}else {
    write-host "no workspace has been set. PLease set a Workspace name to use."
    exit
}

# Write out discard.json
$discardJson = @"
{"comment": "placeholder"}
"@

set-content -Value $discardJson -Path ./discard.template.json

(get-content ./discard.template.json) -Replace 'placeholder', $comment | set-content ./discard.json

#############
Write-Host ""
$discardResult = curl -s --header "Authorization: Bearer $env:token" --header "Content-Type: application/vnd.api+json" --request POST --data `@discard.json https://$env:address/api/v2/runs/$runId/actions/discard

$discardResult
write-host "Run $runId discarded"

# Remove generate content
rm discard.json
rm discard.template.json

