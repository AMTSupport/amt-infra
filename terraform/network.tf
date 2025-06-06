resource "azurerm_virtual_network" "secure_vnet" {
  resource_group_name = azurerm_resource_group.terraform.name
  location            = azurerm_resource_group.terraform.location

  name          = "secure-vnet"
  address_space = ["10.0.0.0/16"]

  subnet {
    name              = "secure-subnet"
    address_prefixes  = ["10.0.0.0/24"]
    security_group    = azurerm_network_security_group.secure_security_group.id
    service_endpoints = ["Microsoft.Storage"]
    # delegation = [
    #   {
    #     name = "Microsoft.ContainerInstance"
    #     service_delegation = [
    #       {
    #         name = "Microsoft.ContainerInstance/containerGroups"
    #         actions = [
    #           "Microsoft.Network/virtualNetworks/subnets/action",
    #         ]
    #       }
    #     ]
    #   }
    # ]
  }
}

resource "azurerm_network_security_group" "secure_security_group" {
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name
  name                = "secure-nsg"

  security_rule {
    name        = "SSH"
    description = "Allow SSH from Permitted IPs"

    access    = "Allow"
    direction = "Inbound"
    priority  = "1010"

    protocol                   = "Tcp"
    destination_address_prefix = "*"
    destination_port_range     = "22"
    source_address_prefixes    = local.permittedIps
    source_port_range          = "*"
  }

  security_rule {
    name = "AllowAnyHTTPInbound"

    access    = "Allow"
    direction = "Inbound"
    priority  = "1040"

    protocol                   = "Tcp"
    destination_address_prefix = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }

  security_rule {
    name = "AllowAnyHTTPSInbound"

    access    = "Allow"
    direction = "Inbound"
    priority  = "1060"

    protocol                   = "Tcp"
    destination_address_prefix = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }

  security_rule {
    name = "AllowAnyHTTPSUDPInbound"

    access    = "Allow"
    direction = "Inbound"
    priority  = "1070"

    protocol                   = "Udp"
    destination_address_prefix = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }

  security_rule {
    name = "WireGuard"

    access    = "Allow"
    direction = "Inbound"
    priority  = "1080"

    protocol                   = "Udp"
    destination_address_prefix = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }
}
