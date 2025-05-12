resource "azurerm_virtual_network" "secure_vnet" {
  resource_group_name = azurerm_resource_group.terraform.name
  location            = azurerm_resource_group.terraform.location

  name          = "secure-vnet"
  address_space = ["10.0.0.0/16"]

  subnet {
    name              = "secure-subnet"
    address_prefixes  = ["10.0.0.0/24"]
    service_endpoints = ["Microsoft.Storage"]
    security_group    = azurerm_network_security_group.secure_security_group.id
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

resource "azurerm_container_group" "caddy" {
  name                = "caddy"
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name

  ip_address_type = "Public"
  dns_name_label  = "caddy"
  os_type         = "Linux"

  container {
    name   = "caddy"
    image  = "caddy:2"
    cpu    = "0.5"
    memory = "0.2"

    environment_variables = {
      "CIPP_ENDPOINT" = module.cipp.cipp_web_host_name
    }

    secure_environment_variables = data.sops_file.secrets.data

    ports {
      port     = 80
      protocol = "TCP"
    }
    ports {
      port     = 443
      protocol = "TCP"
    }
    ports {
      port     = 443
      protocol = "UDP"
    }

    volume {
      name       = "caddy-file"
      mount_path = "/etc/caddy/Caddyfile"
      read_only  = true
      git_repo {
        url       = "https://github.com/AMTSupport/amt-infra.git"
        directory = "caddy"
      }
    }

    volume {
      name                 = "caddy-data"
      mount_path           = "/data"
      storage_account_name = azurerm_storage_account.terraform-backend.name
      storage_account_key  = azurerm_storage_account.terraform-backend.primary_access_key
    }

    volume {
      name                 = "caddy-config"
      mount_path           = "/config"
      storage_account_name = azurerm_storage_account.terraform-backend.name
      storage_account_key  = azurerm_storage_account.terraform-backend.primary_access_key
    }
  }
}
