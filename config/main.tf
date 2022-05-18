resource "azurerm_resource_group" "example" {
  name     = var.rg_name
  location = var.region
}

variable "rg_name" {
  type        = string
  description = "The name for the new Resource Group"
  default = "rg-new_ws"
}

variable "region" {
  type        = string
  description = "The Azure Region to deploy to."
  default     = "uksouth"
}



