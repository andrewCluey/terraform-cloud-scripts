param (
  [Parameter(Mandatory=$true)][string]$workspace,
  [Parameter(Mandatory=$true)][string]$repoIdentifier,
  [string]$organization,
  [string]$TFE_TOKEN,
  [string]$vcsOAuthToken
)

<#
 .SYNOPSIS
 Connects to Terraform Cloud (Enterprise) to create a workspace that is connected to a VCS repo.
 Will perform a new run.
 If workspace already exists, it will simply create a new run in the existing workspace.
 Workspace is not configured to auto apply.

 .DESCRIPTION
 Will create a new Workspace if the specified Workspace does not already exist.
 Creates a Workspace linked to a VCS repository.
 Once workspace is created, a new run will be created and left in the 'pending state'.
 Runs will NOT be auto applied.

 .PARAMETER workspace
 Required: Specifies the Worksp[ace to use or create.

 .PARAMETER repoIdentifier
 Required: the repository to link to the Workspace. 
 Use the following format:
 xxxx/xxxxx

 .PARAMETER organization
 Optional: Will first check local environment variables for $env:organization.
 If no env variable set, then this paramater is required.
 Specifies which Terraform Cloud Organization to create the new Workspace in.

 .PARAMETER vcsOAuthToken
 The OauthToken from Terraform cloud to connect to the VCS provider.

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

$workspaceTemplate = @"
{
  "data": {
    "attributes": {
      "name": "placeholder",
      "resource-count": 0,
      "terraform_version": "1.0.5",
      "working-directory": "",
      "vcs-repo": {
        "identifier": "repoId",
        "oauth-token-id": "oauthtoken",
        "branch": ""
      },
      "updated-at": "2017-11-29T19:18:09.976Z"
    },
    "type": "workspaces"
  }
}
"@

set-content -Value $workspaceTemplate -Path ./workspace.template.json


# Write out variable.template.json
$variabletemplate = @"
{
    "data": {
      "type":"vars",
      "attributes": {
        "key":"my-key",
        "value":"my-value",
        "category":"my-category",
        "hcl":my-hcl,
        "sensitive":my-sensitive
      }
    },
    "filter": {
      "organization": {
        "username":"my-organization"
      },
      "workspace": {
        "name":"my-workspace"
      }
    }
  }
"@

set-content -Value $variableTemplate -Path ./variable.template.json


# Write out run.template.json
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


# Write out apply.json
#$applyJson = @"
#{"comment": "apply via API"}
#"@

#set-content -Value $applyJson -Path ./apply.json





#### Check for Workspace and create if not ####
# 
# Set name of workspace in workspace.json
# use $workspaceTemplate file
####
(get-content ./workspace.template.json) -Replace 'placeholder', $env:workspace -Replace 'repoId', $repoIdentifier -Replace 'oauthtoken', $vcsOAuthToken  | set-content ./workspace.json
$workspaceJson = "./workspace.json"
# Check to see if the workspace already exists
write-host " "
write-host "Checking to see if workspace exists"
$headers = @{
    'Content-Type' = 'application/vnd.api+json'
    'Authorization' = "Bearer $env:token"
}
$uri = "https://$env:address/api/v2/organizations/$env:organization/workspaces/$env:workspace"
$check_workspace_result = $null
$check_workspace_result = Invoke-RestMethod -uri $uri -headers $headers
$jsWorkspace_result = $check_workspace_result
$jsWorkspace_result.data.id
$workspaceId = $jsWorkspace_result.data.id
#$workspaceId = $jsWorkspace_result | jq -r '.data.id'

# Create workspace if it does not already exist
if (!$check_workspace_result) {
    write-host ""
    write-host "Workspace does not exist.... Creating workspace $env:workspace"
    $workspace_result = Invoke-RestMethod -Headers $headers -Method POST -inFile $workspaceJson -Uri "https://$env:address/api/v2/organizations/$env:organization/workspaces"
    $jsWorkspace_result = $workspace_result
    $jsWorkspace_result.data.id
    $workspaceId = $jsWorkspace_result.data.id
    #$workspaceId = $jsWorkspace_result | jq -r '.data.id'
    write-host ""
    write-host "Workspace ID: $workspaceId"
}else {
    write-host ""
    write-host "Workspace already exists"
}


#### Create configuration version ####
# 
# 
# 
####
#$configVersionJson = "./configversion.json"
#write-host ""
#write-host "Creating configuration version."
#$configuration_version_result = Invoke-RestMethod -Headers $headers -Method POST -inFile $configVersionJson -Uri "https://$env:address/api/v2/workspaces/$workspaceId/configuration-versions"

# Parse configuration_version_id and upload_url
#$config_version_id = $configuration_version_result.id
#write-host ""
#$uploadurl = ($configuration_version_result.data.attributes."upload-url")
#write-host "Config Version ID: $config_version_id"
#write-host "Upload URL: $uploadurl"

# Upload configuration
#$uploadConfigHeaders = @{
#  'Content-Type' = 'application/octet-stream'
#}
#write-host ""
#curl -s --header "Content-Type: application/octet-stream" --request PUT --data-binary @$config_tar_file_name "$uploadurl"
##write-host "Uploading configuration version using $config_tar_file_name"


# Check if a variables.csv file is in the configuration directory
# If so, use it. Otherwise, use the one in the current directory.
#if (test-path "$config_dir/variables.csv") {
#  write-host ""
#  write-host "Variables file found in $config_dir"
#  $variablesFile = "$config_dir/variables.csv"
  # Add variables to workspace
#  write-host ""
#  $vars = import-csv $variablesFile | ForEach {
#  $value = $_.value
#    $key = $_.key
#    $category = $_.category
#    $hcl = $_.hcl
#    $sensitive = $_.sensitive

#    ((get-content ./variable.template.json) -Replace 'my-organization', $env:organization -Replace 'my-workspace', $env:workspace `
#        -Replace 'my-key', $key -Replace 'my-value', $value -Replace 'my-category', $category -replace 'my-hcl', $hcl -Replace 'my-sensitive', $sensitive `
#        | set-content ./variables.json)
#      # upload variable set
#    $uploadVariableResult = Invoke-RestMethod -Headers $headers -Method POST -inFile "./variables.json" -Uri "https://$env:address/api/v2/vars?filter%5Borganization%5D%5Bname%5D=$env:organization&filter%5Bworkspace%5D%5Bname%5D=$env:workspace"
#    $varID = $uploadVariableResult.data.id
#    write-host "Variable Id is $varId"
#  }
#}

# Sentinel policies
$sentinelListResult = Invoke-RestMethod -Headers $headers -Uri "https://$env:address/api/v2/organizations/$env:organization/policy-sets"
$sentinelPolicySetCount = $sentinelListResult.meta.pagination."total-count"
write-host ""
write-host "Number of Sentinel policy sets: $sentinelPolicySetCount"

#############
# Perform run
#############
((get-content ./run.template.json) -Replace 'workspace_id', $workspaceId | set-content ./run.json)
$runResult = Invoke-RestMethod -Method POST -Headers $headers -inFile './run.json' -uri "https://$env:address/api/v2/runs"
## Parse run_result
Start-Sleep -Seconds 10

$runId = $runResult.data.id
write-host ""
write-host "Run ID: $runId" #### $runid is crucial for subsequent apply following approval. This needs to be saved back to SNOW.
$env:runId = $runId
write-host "view the run in Terraform Cloud: https://app.terraform.io/app/$organization/workspaces/$workspace/runs/$runId"
write-host ""

rm ./workspace.template.json
rm ./workspace.json
rm ./run.json
rm ./run.template.json
