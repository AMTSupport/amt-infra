# Terraform

Root Terraform module for AMT infrastructure. Provisions Azure and DigitalOcean resources.

## Structure

```text
terraform/
  ├── main.tf         # Module calls: hudu, cipp
  ├── variables.tf    # Locals (preferredLocation, permittedIps, tenantId) + SOPS data source
  ├── provider.tf     # azurerm, digitalocean, sops providers
  ├── backend.tf      # Azure Storage backend (azurerm, use_azuread_auth) + resource group
  ├── network.tf      # VNet (10.0.0.0/16), subnet, NSG rules (SSH, HTTP/S, WireGuard)
  ├── dns.tf          # Service-keyed DNS record map → deepmerge → for_each resources
  ├── secrets.yaml    # SOPS-encrypted (AZURE_SUBSCRIPTION_ID, DIGITALOCEAN_TOKEN, TRUSTED_IPS, etc.)
  ├── hudu/           # DigitalOcean droplet, Azure Storage (live + RAGRS backup), DNS A record
  └── cipp/           # Azure Static Web App, Function App (PowerShell 7.4), Key Vault, private endpoint
```

## Module Pattern

Root module passes shared resources to submodules:

```hcl
module "hudu" {
  source = "./hudu"
  location              = local.preferredLocation
  digitalocean_location = local.digitalocean_location
  dns_zone              = azurerm_dns_zone.amt_root
  ...
}
```

Submodules declare their own `provider.tf` with `required_providers` block (no version pins — inherited from root lock).

## DNS Pattern (dns.tf)

DNS records are organized by service in `locals.services`. Each service key contains record types (A, AAAA, CNAME, MX, SRV, TXT) as maps. All service maps are deepmerged via `Invicton-Labs/deepmerge/null` and iterated with `for_each`.

To add records for a new service:

1. Add a new key in `locals.services` with the appropriate record type maps
1. The deepmerge + `for_each` on each `azurerm_dns_*_record` resource handles the rest automatically

SPF is handled separately in `azurerm_dns_txt_record.spf_record` using `local.SPFIncludes` list — add new SPF includes there, not in the service map.

**Watch out**: The `@` TXT record in `locals.services` (e.g., google site verification) is separate from the SPF `@` record. The SPF record is a dedicated resource (`spf_record`) to avoid conflicts.

## Secrets

All secrets loaded via `data "sops_file" "secrets"` from `secrets.yaml`. Access pattern: `data.sops_file.secrets.data["KEY"]`. Never reference plaintext values.

SOPS creation rule in `.sops.yaml`: path `^terraform/secrets.yaml$` → encrypted for `james` + `terraform` age keys.

## Naming

- Resources: `snake_case` — `azurerm_dns_zone.amt_root`, `azurerm_storage_account.terraform-backend`
- Locals: `camelCase` — `preferredLocation`, `permittedIps`, `tenantId`
- Submodule variables: `snake_case` — `permitted_ips`, `dns_zone`, `secure_subnet`

## Providers

Defined in `flake.nix` under `languages.terraform.package`:

```nix
pkgs.terraform.withPlugins (p: with p; [ azurerm sops digitalocean ])
```

To add a provider: add to this list in `flake.nix` AND add `required_providers` entry in `terraform/provider.tf`.

## Backend

Azure Storage in `australiaeast`, resource group `terraform`, storage account `amttfbackend`, container `tfstate`. Uses Azure AD auth (`use_azuread_auth = true`).

## Anti-patterns

- Never store secrets in `.tf` files — use SOPS
- Never pin provider versions in submodule `provider.tf` — only root lock file
- Never add DNS records outside the `locals.services` + deepmerge pattern (except SPF)
- Never use `terraform.workspace` — single environment, no workspaces
