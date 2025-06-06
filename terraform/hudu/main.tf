resource "azurerm_resource_group" "hudu" {
  location = var.location
  name     = "Hudu"
}

variable "location" {
  description = "The Azure region to deploy resources into."
  type        = string
}

variable "permitted_ips" {
  description = "List of IP addresses that are allowed to access SSH or other sentitive things."
  type        = list(string)
}

variable "digitalocean_location" {
  description = "The DigitalOcean region to deploy resources into."
  type        = string
}

resource "digitalocean_ssh_key" "James_Work_Key" {
  name       = "James Work Key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKR0l+66/jg7SdHgam44I26+yJaEIa7cEO2QBtshzDxb"
}

variable "secure_subnet" {
  description = "The secure subnet instance."
  type = object({
    id   = string
    name = string
  })
}
