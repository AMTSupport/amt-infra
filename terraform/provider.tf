terraform {
  required_providers {
    sops = {
      source = "carlpett/sops"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  subscription_id = data.sops_file.secrets.data["AZURE_SUBSCRIPTION_ID"]
  features {
    subscription {
      prevent_cancellation_on_destroy = true
    }
  }
}
