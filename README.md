# terraform-cloud-scripts
Scripts to connect to Terraform Cloud (Enterprise) using API.

## POwerShell scripts


### ps-createworkspace.ps1

This script will create a workspace from the specified VCS Repository (-repoIdentifier). The Git provider must be linked within Terraform cloud and an oAuthToken provided (-vcsOAuthToken).

### ps-applyrun.ps1

### ps-discardrun.ps1


## policy checks
rreturned data for an advisory failure:
```json  
  "data": {
            "sentinel-policyset-asc-dev": {
              "can-override": false,
              "error": null,
              "policies": [
                {
                  "allowed-failure": true,
                  "error": null,
                  "policy": "sentinel-policyset-asc-dev/enforce-mandatory-tags",
                  "result": false,
                  "trace": {
                    "description": "This policy uses the Sentinel tfplan/v2 import to require that\nspecified Azure resources have all mandatory tags",
                    "error": null,
                    "print": "azurerm_resource_group.rg has tags that is missing, null, or is not a map or a list. It should have had these items: [environment]\n",
                    "result": false,
```

returned data for a hard-mandatory failure:
```json
 "data": {
            "sentinel-policyset-asc-dev": {
              "can-override": false, # a soft-mandatory would allow overrides
              "error": null,
              "policies": [
                {
                  "allowed-failure": false,
                  "error": null,
                  "policy": "sentinel-policyset-asc-dev/enforce-mandatory-tags",
                  "result": false,
                  "trace": {
                    "description": "This policy uses the Sentinel tfplan/v2 import to require that\nspecified Azure resources have all mandatory tags",
                    "error": null,
                    "print": "azurerm_resource_group.rg has tags that is missing, null, or is not a map or a list. It should have had these items: [environment]\n",
                    "result": false,

```

returned data for passed policy:
```json
{
                  "allowed-failure": false,
                  "error": null,
                  "policy": "sentinel-policyset-asc-dev/less-than-10-month",
                  "result": true,
                  "trace": {
                    "description": "",
                    "error": null,
                    "print": "",
                    "result": true,
```

Status shows results of entire policy set run:

data.status
```json
"status": "hard_failed",
```


data.status
```json
"status": "passed",
```


data.status
```json
 "status": "soft_failed",
 ```