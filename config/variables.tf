variable "region" {
  type        = string
  description = "The Azure Region to deploy to."
  default     = "uksouth"
}

variable "environment" {
  type        = string
  description = "The staging environment for the new deployment."
  default     = "Dev"
}

variable "rg_name" {
  type        = string
  description = "The name for the new Resource Group"
  default     = "rg-mid-csx"
}


variable "tags" {
  type        = map(any)
  description = "OPTIONAL: A map object to define additional tags to assign to all resources."
  default     = {}
}
