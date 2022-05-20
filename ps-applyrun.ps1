param (
    [Parameter(Mandatory=$true)][string]$workspace,
    [Parameter(Mandatory=$true)][string]$runId,
    [string]$organization,
    [string]$gitUrl,
    [string]$terraformConfigDirectory,
    [string]$comment
)

<#
 .SYNOPSIS
 Connects to Terraform Cloud or Enterprise Instance and creates & Runs a new configuration.
 

 .DESCRIPTION
 Will create a new Workspace if the specified Workspace does not already exist.
 Will download Terraform config from a Git URL if specified.
 Will default to using the local `config` directory if no Git URL specified.

 .PARAMETER workspace
 Required: Specifies the Worksp[ace to use or create.

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
        write-host "TOKEN environment variable not set."
        exit
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


# Write out apply.json
cat > apply.json <<EOF
{"comment": "$comment"}
EOF

#############
Write-Host ""
$apply_result = curl -s --header "Authorization: Bearer $TFE_TOKEN" --header "Content-Type: application/vnd.api+json" --data @apply.json https://$address/api/v2/runs/$runId/actions/apply

# Get run details including apply information
$check_result = curl -s --header "Authorization: Bearer $TFE_TOKEN" --header "Content-Type: application/vnd.api+json" https://$address/api/v2/runs/$runId?include=apply

# Get apply ID
$apply_id = $check_result.included[0].id
write-host "Apply ID: $apply_id"

# Check apply status periodically in loop


# Remove any generated files and user content (git download directories)