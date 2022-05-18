#!/bin/bash
# Script that clones Terraform configuration from a git repository
# creates a workspace if it does not already exist, uploads the
# Terraform configuration to it, adds variables to the workspace,
# triggers a run, checks the results of Sentinel policies (if any)
# checked against the workspace, and if $override=true and there were
# no hard-mandatory violations of Sentinel policies, does an apply.
# If an apply is done, the script waits for it to finish and then
# downloads the apply log and the state file.

# Make sure TFE_TOKEN and TFE_ORG environment variables are set
# to owners team token and organization name for the respective
# TFE environment. TFE_ADDR should be set to the FQDN/URL of the private
# TFE server or if unset it will default to TF Cloud/SaaS address.


# Key params - REQUIRES INPUT
run_id="run-qTx1FVHhNkEdY1LR"
apply=true



####
if [ ! -z "$TFE_TOKEN" ]; then
  token=$TFE_TOKEN
  echo "TFE_TOKEN environment variable was found."
else
  echo "TFE_TOKEN environment variable was not set."
  echo "You must export/set the TFE_TOKEN environment variable."
  echo "It should be a user or team token that has write or admin"
  echo "permission on the workspace."
  echo "Exiting."
  exit
fi

# Evaluate $TFE_ORG environment variable
# If not set, give error and exit
if [ ! -z "$TFE_ORG" ]; then
  organization=$TFE_ORG
  echo "TFE_ORG environment variable was set to ${TFE_ORG}."
  echo "Using organization, ${organization}."
else
  echo "You must export/set the TFE_ORG environment variable."
  echo "Exiting."
  exit
fi

# Evaluate $TFE_ADDR environment variable if it exists
# Otherwise, use "app.terraform.io"
# You should edit these before running the script.
if [ ! -z "$TFE_ADDR" ]; then
  address=$TFE_ADDR
  echo "TFE_ADDR environment variable was set to ${TFE_ADDR}."
  echo "Using address, ${address}"
else
  address="app.terraform.io"
  echo "TFE_ADDR environment variable was not set."
  echo "Using Terraform Cloud (TFE SaaS) address, app.terraform.io."
  echo "If you want to use a private TFE server, export/set TFE_ADDR."
fi

# workspace name should not have spaces and should be set as second
# argument from CLI

workspace="workspace-from-api" # change to accept input

# You can change sleep duration if desired
sleep_duration=5

# Get first argument.
# If not "", Set to git clone URL
# and clone the git repository
# If "", then load code from config directory
if [ ! -z $1 ]; then
  git_url=$1
  config_dir=$(echo $git_url | cut -d "/" -f 5 | cut -d "." -f 1)
  if [ -d "${config_dir}" ]; then
    echo "removing existing directory ${config_dir}"
    rm -fr ${config_dir}
  fi
  echo "Cloning from git URL ${git_url} into directory ${config_dir}"
  git clone -q ${git_url}
else
  echo "Will take code from config directory."
  git_url=""
  config_dir="config"
fi

# Set workspace if provided as the second argument
if [ ! -z "$2" ]; then
  workspace=$2
  echo "Using workspace provided as argument: " $workspace
else
  echo "Using workspace set in the script: " $workspace
fi

# Make sure $workspace does not have spaces
if [[ "${workspace}" != "${workspace% *}" ]] ; then
    echo "The workspace name cannot contain spaces."
    echo "Please pick a name without spaces and run again."
    exit
fi


# Write out workspace.template.json
cat > workspace.template2.json <<EOF
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
EOF

# Write out configversion.json
cat > configversion.json <<EOF
{
  "data": {
    "type": "configuration-versions",
    "attributes": {
      "auto-queue-runs": false
    }
  }
}
EOF

# Write out variable.template.json
cat > variable.template.json <<EOF
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
EOF

# Write out run.template.json
cat > run.template.json <<EOF
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
EOF

# Write out apply.json
cat > apply.json <<EOF
{"comment": "apply via API"}
EOF


############
############

# Better way to deal with variables. Currently cannot be updated via this Script.


############
############

#############
#############

# Get run_status
# get `confirmable status`
# get apply status

#############
#############

  # Run is planning - get the plan

  # planned means plan finished and no Sentinel policy sets
  # exist or are applicable to the workspace
  if [[ "$apply" == "true" ]]; then
    echo ""
    echo "`apply` parameter was set to `true` so Terraform configuration will be applied as described in the plan."
    # Do the apply
    apply_result=$(curl -s --header "Authorization: Bearer $TFE_TOKEN" --header "Content-Type: application/vnd.api+json" --data @apply.json https://${address}/api/v2/runs/${run_id}/actions/apply)
    applied="true"

  # errored means that plan had an error or that a hard-mandatory
  # policy failed
#  elif [[ "$run_status" == "errored" ]]; then
#    echo ""
#    echo "Plan errored or hard-mandatory policy failed"
#    save_plan="true"
#    continue=0
#  elif [[ "$run_status" == "planned_and_finished" ]]; then
#    echo ""
#    echo "Plan indicates no changes to apply."
#    save_plan="true"
#    continue=0
#  elif [[ "run_status" == "canceled" ]]; then
#    echo ""
#    echo "The run was canceled."
#    continue=0
#  elif [[ "run_status" == "force_canceled" ]]; then
#    echo ""
#    echo "The run was canceled forcefully."
#    continue=0
#  elif [[ "run_status" == "discarded" ]]; then
#    echo ""
#    echo "The run was discarded."
#    continue=0
  else
    # Sleep and then check status again in next loop
    echo "We will sleep and try again soon."
  fi


# Get the apply log and state file if an apply was done
if [[ "$applied" == "true" ]]; then

  echo ""
  echo "An apply was done."
  echo "Will download apply log and state file."

  # Get run details including apply information
  check_result=$(curl -s --header "Authorization: Bearer $TFE_TOKEN" --header "Content-Type: application/vnd.api+json" https://${address}/api/v2/runs/${run_id}?include=apply)

  # Get apply ID
  apply_id=$(echo $check_result | jq -r '.included[0].id')
  echo ""
  echo "Apply ID:" $apply_id

  # Check apply status periodically in loop
  continue=1
  while [ $continue -ne 0 ]; do

    sleep $sleep_duration
    echo ""
    echo "Checking apply status"

    # Check the apply status
    check_result=$(curl -s --header "Authorization: Bearer $TFE_TOKEN" --header "Content-Type: application/vnd.api+json" https://${address}/api/v2/applies/${apply_id})

    # Parse out the apply status
    apply_status=$(echo $check_result | jq -r '.data.attributes.status')
    echo "Apply Status: ${apply_status}"

    # Decide whether to continue
    if [[ "$apply_status" == "finished" ]]; then
      echo "Apply finished."
      continue=0
    elif [[ "$apply_status" == "errored" ]]; then
      echo "Apply errored."
      continue=0
    elif [[ "$apply_status" == "canceled" ]]; then
      echo "Apply was canceled."
      continue=0
    else
      # Sleep and then check apply status again in next loop
      echo "We will sleep and try again soon."
    fi
  done

  # Get apply log URL
  apply_log_url=$(echo $check_result | jq -r '.data.attributes."log-read-url"')
  echo ""
  echo "Apply Log URL:"
  echo "${apply_log_url}"

  # Retrieve Apply Log from the URL
  # and output to shell and file
  echo ""
  curl -s $apply_log_url | tee ${apply_id}.log

  # Get state version ID from after the apply
  state_id=$(echo $check_result | jq -r '.data.relationships."state-versions".data[0].id')
  echo ""
  echo "State ID:" ${state_id}

  # Call API to get information about the state version including its URL and outputs
  state_file_url_result=$(curl -s --header "Authorization: Bearer $TFE_TOKEN" "https://${address}/api/v2/state-versions/${state_id}?include=outputs")

  # Retrieve and echo outputs from state
  # Note that we retrieved outputs in the last API call by
  # adding `?include=outputs`
  # Instead of doing that, we could have retrieved the state version output
  # IDs from the relationships of the above API call and could have then
  # called the State Version Output API to retrieve details for each output.
  # That would have involved URLs like
  # "https://${address}/api/v2/state-version-outputs/${output_id}"
  # See `https://www.terraform.io/docs/cloud/api/state-version-outputs.html#show-a-state-version-output`
  num_outputs=$(echo $state_file_url_result | jq -r '.included | length')
  echo ""
  echo "Outputs from State:"
  for ((output=0;output<$num_outputs;output++))
  do
    echo $state_file_url_result | jq -r --arg OUTPUT $output '.included[$OUTPUT|tonumber].attributes'
  done

  # Get state file URL from the result
  state_file_url=$(echo $state_file_url_result | jq -r '.data.attributes."hosted-state-download-url"')
  echo ""
  echo "URL for state file after apply:"
  echo ${state_file_url}

  # Retrieve state file from the URL
  # and output to shell and file
  echo ""
  echo "State file after the apply:"
  curl -s $state_file_url | tee ${apply_id}-after.tfstate

fi

# Remove json files
rm apply.json
rm configversion.json
rm run.template.json
rm run.json
rm variable.template.json
rm variable.json
rm workspace.template.json
rm workspace.json

echo "Finished"
