#!/bin/bash
# Script that discards a run (rejected). Terraform configuration from a git repository
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

# required arguments:
# -r : enter the run_id as returned in the original configuration request.

# Key params
discard=true

# set input arguments
while getopts r:c: flag
do
    case "${flag}" in
        r) run_id=${OPTARG};;
        c) comment=${OPTARG};;
    esac
done


# Set the run_id paramater from input argument
if [ ! -z $run_id ]; then
  run_id=$run_id
  echo "Discarding the plan found in Run ${run_id}"
else
  echo "no run_id has been set."
  echo "Exiting!"
  exit
fi

if [ ! -z $comment ]; then
  comment=$comment
  echo "Setting comment to ${comment}"
else
  comment="default comment."
fi


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

# You can change sleep duration if desired
sleep_duration=5

# Write out discard.json
cat > discard.template.json <<EOF
{"comment": "placeholder"}
EOF

#Set comment into discard job.
sed "s/placeholder/${comment}/" < discard.template.json > discard.json



########################
# Discard the Run
########################

  if [[ "$discard" == "true" ]]; then
    echo ""
    echo "`discard` parameter is set to `true` so run $run_id will be discarded."
    # Discard the run
    discard_result=$(curl -s --header "Authorization: Bearer $TFE_TOKEN" --header "Content-Type: application/vnd.api+json" --request POST --data @discard.json https://${address}/api/v2/runs/${run_id}/actions/discard)
  else
    echo "Script not configured to perform the discard task. Set the 'discard' variable to true."
  fi

############
# IMPORVE LOGGING
############
# Remove json files
rm discard.template.json
rm discard.json

echo "Finished"