param (
  [Parameter(Mandatory=$true)][string]$workspace,  
  [string]$organization,
  [string]$gitUrl,
  [string]$TFE_TOKEN
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
    write-host "no workspace has been set. PLease set a Workspace name to use."
    exit
}


# Clone Git Repo
# If GitRepo not set, then load code from config directory
if ($gitUrl) {
  $trimmedName = $gitURL.Split('/')[-1] 
  $config_dir_name = $trimmedName -replace ".{4}$"
  $config_dir = "./$config_dir_name"
}else {
  write-host "no config directory has been set. Using 'config'"
  $config_dir_name = "config"
  $config_dir = "./config"

}

$config_tar_file_name = "$config_dir_name.tar.gz"


# build compressed tar file from configuration directory
write-host "Tarring configuration directory."
tar -cvzf $config_tar_file_name -C $config_dir --exclude .git .

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
$applyJson = @"
{"comment": "apply via API"}
"@

set-content -Value $applyJson -Path ./apply.json


#### Check for Workspace and create if not ####
# 
# Set name of workspace in workspace.json
# use $workspaceTemplate file
####
(get-content ./workspace.template.json) -Replace 'placeholder', $env:workspace | set-content ./workspace.json
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
$jsWorkspace_result = $check_workspace_result | convertTo-Json -Depth 10
$workspaceId = $jsWorkspace_result | jq -r '.data.id'

# Create workspace if it does not already exist
if (!$check_workspace_result) {
    write-host ""
    write-host "Workspace does not exist.... Creating workspace $env:workspace"
    $workspace_result = Invoke-RestMethod -Headers $headers -Method POST -inFile $workspaceJson -Uri "https://$env:address/api/v2/organizations/$env:organization/workspaces"
    $jsWorkspace_result = $workspace_result | convertTo-Json  -Depth 10
    $workspaceId = $jsWorkspace_result | jq -r '.data.id'
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
$configVersionJson = "./configversion.json"
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
}
write-host ""
write-host "Uploading configuration version using $config_tar_file_name"
curl -s --header "Content-Type: application/octet-stream" --request PUT --data-binary @$config_tar_file_name "$uploadurl"


# Check if a variables.csv file is in the configuration directory
# If so, use it. Otherwise, use the one in the current directory.
if (test-path "$config_dir/variables.csv") {
  write-host ""
  write-host "Variables file found in $config_dir"
  $variablesFile = "$config_dir/variables.csv"
  # Add variables to workspace
  write-host ""
  $vars = import-csv $variablesFile | ForEach {
    $key = $_.key
    $value = $_.value
    $category = $_.category
    $hcl = $_.hcl
    $sensitive = $_.sensitive

    ((get-content ./variable.template.json) -Replace 'my-organization', $env:organization -Replace 'my-workspace', $env:workspace `
        -Replace 'my-key', $key -Replace 'my-value', $value -Replace 'my-category', $category -replace 'my-hcl', $hcl -Replace 'my-sensitive', $sensitive `
        | set-content ./variables.json)
      # upload variable set
    $uploadVariableResult = Invoke-RestMethod -Headers $headers -Method POST -inFile "./variables.json" -Uri "https://$env:address/api/v2/vars?filter%5Borganization%5D%5Bname%5D=$env:organization&filter%5Bworkspace%5D%5Bname%5D=$env:workspace"
    $varID = $uploadVariableResult.data.id
    write-host "Variable Id is $varId"
  }
}

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
# Parse run_result
Start-Sleep -Seconds 10

$runId = $runResult.data.id
write-host ""
write-host "Run ID: $runId" #### $runid is crucial for subsequent apply following approval. This needs to be saved back to SNOW.
$env:runId = $runId
write-host "view the run in Terraform Cloud: https://app.terraform.io/app/$organization/workspaces/$workspace/runs/$runId"
write-host ""


rm workspace.json
rm workspace.template.json
rm run.json
rm run.template.json
rm config.tar.gz
rm configversion.json

