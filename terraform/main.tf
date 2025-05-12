# module "hudu" {
#   source = "./hudu"
#   providers = {
#     azurerm = azurerm
#   }

#   location      = local.preferredLocation
# }

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



