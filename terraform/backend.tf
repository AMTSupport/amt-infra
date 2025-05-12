resource "azurerm_resource_group" "terraform" {
  name     = "terraform"
  location = local.preferredLocation
}

resource "azurerm_storage_account" "terraform-backend" {
  resource_group_name      = azurerm_resource_group.terraform.name
  location                 = local.preferredLocation
  name                     = "amttfbackend"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.terraform-backend.id
  container_access_type = "private"
}

terraform {
  backend "azurerm" {
    use_azuread_auth     = true
    resource_group_name  = "terraform"
    storage_account_name = "amttfbackend"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
