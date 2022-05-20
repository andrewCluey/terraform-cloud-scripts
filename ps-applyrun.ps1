param (
    [Parameter(Mandatory=$true)][string]$workspace,
    [Parameter(Mandatory=$true)][string]$runId,
    [string]$TFE_TOKEN,
    [string]$organization,
    [string]$gitUrl,
    [string]$terraformConfigDirectory,
    [string]$comment
)

<#
 .SYNOPSIS
 Connects to Terraform Cloud and applies the run specified in the `runId` parameter.
 

 .DESCRIPTION
 Will create a new Workspace if the specified Workspace does not already exist.
 Will download Terraform config from a Git URL if specified.
 Will default to using the local `config` directory if no Git URL specified.

 .PARAMETER workspace
 Required: Specifies the Workspace to use or create.

 .PARAMETER runId
 Required: The Run ID that you wish to apply. 

 .PARAMETER organization
 Optional: Will first check local environment variables for $env:organization.
 If no env variable set, then this paramater is required.
 Specifies which Terraform Cloud Organization to create the new Workspace in.

 .PARAMETER giturl
 Not yet in use
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
    $env:workspace = $workspace
}


# Write out apply.json
$applyJsonTemplate = @"
{"comment": "apply API"}
"@

set-content -Value $applyJsonTemplate -Path ./apply.json
$applyJson = "apply.json"
Write-Host ""
$applyResult = curl -s --header "Authorization: Bearer $env:token" --header "Content-Type: application/vnd.api+json" --request POST --data `@apply.json https://$env:address/api/v2/runs/$runId/actions/apply

# Get run details including apply information
Start-Sleep -Seconds 10
$check_result = curl -s --header "Authorization: Bearer $env:token" --header "Content-Type: application/vnd.api+json" https://$env:address/api/v2/runs/$runId?include=apply

# Get apply ID
$apply_id = $check_result | jq -r .included[0].id
write-host "Apply ID: $apply_id"

# Check apply status periodically in loop

# Remove any generated files and user content (git download directories)
rm apply.json