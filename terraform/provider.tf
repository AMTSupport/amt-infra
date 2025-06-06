terraform {
  required_providers {
    sops = {
      source = "carlpett/sops"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
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

provider "digitalocean" {
  token = data.sops_file.secrets.data["DIGITALOCEAN_TOKEN"]
}
