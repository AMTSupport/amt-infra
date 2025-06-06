resource "azurerm_storage_account" "hudustore" {
  resource_group_name = azurerm_resource_group.hudu.name
  location            = azurerm_resource_group.hudu.location
  name                = "hudustore"

  access_tier                       = "Hot"
  account_kind                      = "StorageV2"
  account_replication_type          = "RAGRS"
  account_tier                      = "Standard"
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  blob_properties {
    change_feed_enabled      = true
    last_access_time_enabled = false
    versioning_enabled       = true

    delete_retention_policy {
      days                     = "35"
      permanent_delete_enabled = false
    }

    restore_policy {
      days = "30"
    }
  }
}

resource "azurerm_storage_account" "hudustore_backup" {
  resource_group_name = azurerm_resource_group.hudu.name
  location            = azurerm_resource_group.hudu.location
  name                = "hudustorebackup"

  access_tier              = "Cool"
  account_kind             = "StorageV2"
  account_replication_type = "RAGRS"
  account_tier             = "Standard"

  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
}

resource "azurerm_storage_account_network_rules" "hudustore_network_rules" {
  for_each = tomap({
    "hudustore"        = azurerm_storage_account.hudustore,
    "hudustore_backup" = azurerm_storage_account.hudustore_backup
  })

  storage_account_id = each.value.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]
  virtual_network_subnet_ids = [
    "/subscriptions/837424af-fe17-436a-a425-bff6e467f53c/resourceGroups/AMT_ResourceGroup/providers/Microsoft.Network/virtualNetworks/Hudu-vnet/subnets/default",
    var.secure_subnet.id,
  ]
  ip_rules = concat(
    var.permitted_ips,
    [digitalocean_droplet.hudu.ipv4_address]
  )
}
