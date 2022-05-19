locals {
  default_tags = {
    environment = var.environment
  }
  assigned_tags = merge(local.default_tags, var.tags)
}

resource "azurerm_resource_group" "example" {
  name     = var.rg_name
  location = var.region
  tags     = local.assigned_tags
}
