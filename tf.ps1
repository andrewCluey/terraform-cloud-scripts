param (
    [string]$workspace,
    [string]$gitUrl,
    [string]$organization,
    [string]$terraformConfigDirectory,
    [string]$requestId

)
$requestID = "rfc123456NEW"
# set Environment Variables
# Check that the `TFE_TOKEN` environment variable is set.
if (Test-Path env:token) {
    write-host "TOKEN was found."
    }else {
        write-host "Terraform Cloud Token has not been set."
        exit
    }

# Evaluate ORGANIZATION environment variable
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

# Set config directory Var
if ($terraformConfigDirectory) {
    $env:config_dir = $terraformConfigDirectory
    write-host "The config directory name has been set to $env:config_dir"
}else {
    write-host "no config directory has been set. Using 'config'"
    $env:config_dir = "config"
}

# Set Workspace var
if ($requestId) {
    $env:workspace = $requestId
    write-host "The workspace to use is configured as $env:workspace"
}else {
    write-host "no workspace has been set. PLease set a Workspace name to use."
}



# Write out workspace.template.json
$workspaceTemplate = @"
{
    "data":
    {
      "attributes": {
        "name":"placeholder",
        "terraform-version": "1.0.5"
      },
      "type":"workspaces"
    }
  }
"@

set-content -Value $workspaceTemplate -Path ./workspace.template.json


$runtemplate = @"
{
    "data": {
      "attributes": {
        "is-destroy":false
      },
      "type":"runs",
      "relationships": {
        "workspace": {
          "data": {
            "type": "workspaces",
            "id": "workspace_id"
          }
        }
      }
    }
  }
"@

set-content -Value $runtemplate -Path ./run.template.json

# Write out configversion.json
$configversion = @"
{
  "data": {
    "type": "configuration-versions",
    "attributes": {
      "auto-queue-runs": false
    }
  }
}
"@

set-content -Value $configversion -Path ./configversion.json

# Write out apply.json
$applyJson = @"
{"comment": "apply via API"}
"@

set-content -Value $applyJson -Path ./apply.json

write-host "Tarring configuration directory."
tar -zcvf "./$env:config_dir.tar.gz" -C "$env:config_dir" --exclude './.terraform/' --exclude './.terraform.lock.hcl' --exclude './cloud.tf' .

# Create terraform cloud backend & Workspace
(get-content ./template.cloud.tf) -Replace 'placeholder', $requestID | set-content ./cloud.tf
copy-item cloud.tf ./config/cloud.tf
# 

cd $env:config_dir

terraform init

# Get workspace ID

cd ..

#### Check for Workspace ID ####
# 
# Set name of workspace in workspace.json
# use $workspaceTemplate file
####
(get-content ./workspace.template.json) -Replace 'placeholder', $env:workspace | set-content ./workspace.json
$workspaceJson = "./workspace.json"

write-host " "
write-host "Checking to see if workspace exists"
$headers = @{
    'Content-Type' = 'application/vnd.api+json'
    'Authorization' = "Bearer $env:token"
}
$uri = "https://$env:address/api/v2/organizations/$env:organization/workspaces/$env:workspace"
$check_workspace_result = $null
$check_workspace_result = Invoke-RestMethod -uri $uri -headers $headers
$workspaceId = $check_workspace_result.data.id
write-host "Workspace ID: $workspaceId"



# Get config version ID
$configVersionJson = "./configVersion.json"
write-host ""
write-host "Creating configuration version."
$configuration_version_result = Invoke-RestMethod -Headers $headers -Method POST -inFile $configVersionJson -Uri "https://$env:address/api/v2/workspaces/$workspaceId/configuration-versions"

# Parse configuration_version_id and upload_url
$config_version_id = $configuration_version_result.id
$uploadurl = ($configuration_version_result.data.attributes."upload-url")
write-host ""
write-host "Config Version ID: $config_version_id"
write-host "Upload URL: $uploadurl"

# Upload configuration
$uploadConfigHeaders = @{
  'Content-Type' = 'application/octet-stream'
  'Authorization' = "Bearer $env:token"
}
write-host ""
write-host "Uploading configuration version using $env:config_dir.tar.gz"
$uploadConfig = curl -s --header "Content-Type: application/octet-stream" --request PUT --data-binary @${config_dir}.tar.gz $uploadurl
$uploadConfig



((get-content ./run.template.json) -Replace 'workspace_id', $workspaceId | set-content ./run.json)
$runResult = Invoke-RestMethod -Method POST -Headers $headers -inFile './run.json' -uri "https://$env:address/api/v2/runs"
# Parse run_result
Start-Sleep -Seconds 15
$runId = $runResult.data.id
write-host ""
write-host "Run ID: $run_id"


$tfplan = terraform plan -var "rg_name=rg-fromcli"





