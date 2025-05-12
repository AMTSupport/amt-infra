resource "azurerm_private_endpoint" "cipp_endpoint" {
  resource_group_name = azurerm_resource_group.cipp.name
  location            = azurerm_resource_group.cipp.location
  name                = "CIPP"

  ip_configuration {
    name               = "CIPP-secure-nic-ipconfig"
    private_ip_address = "10.0.0.5"
    subresource_name   = "staticSites"
  }

  custom_network_interface_name = "CIPP-secure-nic"
  subnet_id                     = var.secure_subnet.id

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.cipp_private_dns_zone.id]
  }

  private_service_connection {
    is_manual_connection           = false
    name                           = "CIPP-secure"
    private_connection_resource_id = azurerm_static_web_app.cipp_web.id
    subresource_names              = ["staticSites"]
  }
}

resource "azurerm_private_dns_zone" "cipp_private_dns_zone" {
  resource_group_name = azurerm_resource_group.cipp.name
  name                = "privatelink.5.azurestaticapps.net"

  soa_record {
    email = "azureprivatedns-host.microsoft.com"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "cipp_dns_link" {
  resource_group_name = azurerm_resource_group.cipp.name
  name                = "cipp_dns_link"

  private_dns_zone_name = azurerm_private_dns_zone.cipp_private_dns_zone.name
  virtual_network_id    = var.secure_vnet.id
}
