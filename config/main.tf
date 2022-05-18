resource "azurerm_resource_group" "example" {
  name     = var.rg_name
  location = var.region
}

variable "rg_name" {
  type        = string
  description = "The name for the new Resource Group"
  default = "rrg-new-app-3"
}

variable "region" {
  type        = string
  description = "The Azure Region to deploy to."
  default     = "uksouth"
}



