locals {
  preferredLocation = "australiaeast"

  permittedIps = split(",", data.sops_file.secrets.data.TRUSTED_IPS)

  tenantId = data.sops_file.secrets.data["AZURE_TENANT_ID"]
}

data "sops_file" "secrets" {
  source_file = "secrets.yaml"
}
