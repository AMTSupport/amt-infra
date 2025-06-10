resource "azurerm_storage_account" "cipp-storage" {
  resource_group_name = azurerm_resource_group.cipp.name
  location            = azurerm_resource_group.cipp.location
  name                = "cippstgwrcio"

  account_kind             = "Storage"
  account_replication_type = "LRS"
  account_tier             = "Standard"

  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  dns_endpoint_type               = "Standard"
}

resource "azurerm_key_vault" "cipp_vault" {
  resource_group_name = azurerm_resource_group.cipp.name
  location            = azurerm_resource_group.cipp.location
  tenant_id           = var.tenant_id

  name     = "cippwrcio"
  sku_name = "standard"
}
