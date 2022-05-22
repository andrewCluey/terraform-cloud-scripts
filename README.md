# terraform-cloud-scripts
Scripts to connect to Terraform Cloud (Enterprise) using API.

## POwerShell scripts


### ps-createworkspace.ps1

This script will create a workspace from the specified VCS Repository (-repoIdentifier). The Git provider must be linked within Terraform cloud and an oAuthToken provided (-vcsOAuthToken).

### ps-applyrun.ps1

### ps-discardrun.ps1