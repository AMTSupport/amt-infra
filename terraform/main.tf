module "hudu" {
  source = "./hudu"
  providers = {
    azurerm      = azurerm
    digitalocean = digitalocean
  }

  location              = local.preferredLocation
  secure_subnet         = one(azurerm_virtual_network.secure_vnet.subnet)
  permitted_ips         = local.permittedIps
  digitalocean_location = local.digitalocean_location
  dns_zone              = azurerm_dns_zone.amt_root
}

module "cipp" {
  source = "./cipp"
  providers = {
    azurerm = azurerm
  }

  location      = local.preferredLocation
  secure_vnet   = azurerm_virtual_network.secure_vnet
  secure_subnet = one(azurerm_virtual_network.secure_vnet.subnet)
  tenant_id     = local.tenantId
}
