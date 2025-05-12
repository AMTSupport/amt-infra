variable "location" {
  description = "The Azure region to deploy resources into."
  type        = string
}

variable "secure_vnet" {
  description = "The secure virtual network instance."
  type = object({
    id   = string
    name = string
  })
}

variable "secure_subnet" {
  description = "The secure subnet instance."
  type = object({
    id   = string
    name = string
  })
}

variable "tenant_id" {
  description = "The tenant ID for the Azure subscription."
  type        = string
}

resource "azurerm_resource_group" "cipp" {
  location = "australiaeast"
  name     = "CIPP"
}


