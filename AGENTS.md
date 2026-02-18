# AMT Infrastructure

IaC monorepo for Applied Marketing Technologies (amt.com.au), an Australian MSP/IT company. Dual approach: Terraform provisions cloud resources on Azure + DigitalOcean; NixOS configures servers via Nix Flakes.

## Architecture

```text
flake.nix                  # Root flake — devenv, treefmt, nixosConfigurations.hudu
terraform/                 # Root Terraform module (Azure + DO)
  ├── hudu/                # Submodule: DigitalOcean droplet, Azure Storage, DNS
  ├── cipp/                # Submodule: Azure Static Web App + Function App
  ├── dns.tf               # Service-keyed DNS record map (deepmerge pattern)
  └── secrets.yaml         # SOPS-encrypted Terraform secrets
hosts/
  ├── hudu/                # NixOS host: Podman containers, Caddy, WireGuard, PG, Redis
  │   ├── application/     # Hudu Rails app — custom-patched Docker image
  │   ├── proxy.nix        # Caddy reverse proxy (most complex file)
  │   ├── wireguard.nix    # WireGuard VPN server
  │   ├── database.nix     # PostgreSQL 16 + Redis
  │   ├── s3.nix           # S3 proxy (Azure Blob → S3-compatible API)
  │   └── secrets.yaml     # SOPS-encrypted host secrets
  └── shared/              # Shared NixOS modules (SSH, SOPS, Nix, swap, generators)
users/                     # VPN users — each dir has default.nix + secrets.yaml
utils/                     # Nushell scripts: new-user.nu, get-wireguard-conf.nu
```

## Critical Rules

- **VCS is Jujutsu (jj)** — git commands are blocked by the jj-opencode plugin. Use `jj` exclusively.
- **Podman, not Docker** — `docker.enable = lib.mkForce false` in hosts/hudu/default.nix. All containers use Podman with `dockerSocket.enable = true`.
- **SOPS + age encryption** — never commit plaintext secrets. Keys defined in `.sops.yaml`. Admin key: james. Host keys: hudu, terraform.
- **Pre-commit hooks are auto-generated** by Nix git-hooks module. The `.pre-commit-config.yaml` header says `# DO NOT MODIFY`. Never edit it directly — change `git-hooks.hooks` in `flake.nix` instead.
- **Single environment** — no dev/staging/prod. Everything is production.
- **Region**: Azure `australiaeast`, DigitalOcean `syd1`.

## Naming Conventions

| Context                  | Convention                | Example                                           |
| ------------------------ | ------------------------- | ------------------------------------------------- |
| Nix variables/attributes | camelCase                 | `huduDomain`, `selectedUser`, `preferredLocation` |
| Terraform resources      | snake_case                | `azurerm_dns_zone.amt_root`                       |
| Terraform locals         | camelCase                 | `preferredLocation`, `permittedIps`               |
| User directories         | lowercase                 | `users/james/`, `users/taurean/`                  |
| Nix files                | kebab-case or single word | `default.nix`, `database.nix`                     |

## Nix Style

- 2-space indent, LF line endings, UTF-8 (`.editorconfig`)
- `nixpkgs` pinned to `nixos-25.05`
- Pipe operators used extensively: `|> builtins.attrNames |> map`
- `flake` (not `self`) passed via `specialArgs` — access as `flake` in modules
- `inputs` in modules refers to `inputs'` (system-resolved) from `withSystem`
- `lib.mkForce` used to override srvos defaults (e.g., docker, cloud-init)
- `lib.getExe` / `lib.getExe'` preferred over `${pkg}/bin/name`
- Unfree packages: only `terraform` — `allowUnfreePredicate = pkg: pkg.pname == "terraform"`

## Terraform Style

- Root module in `terraform/` calls submodules `hudu/` and `cipp/` via `module` blocks
- Secrets via `data "sops_file" "secrets"` → `data.sops_file.secrets.data["KEY"]`
- Backend: Azure Storage (`azurerm` backend with `use_azuread_auth`)
- DNS: service-keyed map in `locals.services` → deepmerged → iterated with `for_each`

## Formatting & Linting

Managed by treefmt via Nix. Formatters: `terraform fmt`, `nixfmt`, `actionlint`, `prettier`, `shellcheck`, `mdformat`, `hclfmt`, `deadnix`, `nixf-diagnose`.

Disabled tools (with reasons):

- `statix` — blocked by [oppiliappan/statix#88](https://github.com/oppiliappan/statix/issues/88)
- `nil` pre-commit hook — waiting for pipe-operators support in nixpkgs stable

Run formatter: `nix fmt` (or `treefmt` inside devenv shell).

## Dev Environment

Enter with `direnv allow` or `nix develop`. Provides: age, azure-cli, caddy, dive, git, openssh, sops, ssh-to-age, wireguard-tools, nil, nix-tree, terraform (with azurerm/sops/digitalocean plugins), plus all treefmt formatters.

## CI Workflows (.github/workflows/)

| Workflow           | Trigger  | Purpose                                              |
| ------------------ | -------- | ---------------------------------------------------- |
| `flake.yaml`       | push     | Nix flake check                                      |
| `formatting.yaml`  | push     | treefmt check                                        |
| `gitguardian.yaml` | push/PR  | Secret scanning                                      |
| `hosts.yaml`       | push     | Build NixOS host configurations                      |
| `terraform.yaml`   | push     | Terraform plan/apply                                 |
| `update.yaml`      | schedule | Automated dependency updates (Renovate + flake lock) |

## Where to Look

| Task                       | Start here                                                           |
| -------------------------- | -------------------------------------------------------------------- |
| Add a DNS record           | `terraform/dns.tf` → `locals.services` map                           |
| Add a new VPN user         | Run `utils/new-user.nu`, then update `.sops.yaml` if needed          |
| Modify Caddy proxy rules   | `hosts/hudu/proxy.nix` (global config + snippets)                    |
| Add a Caddy virtual host   | Relevant module in `hosts/hudu/` via `services.caddy.virtualHosts`   |
| Change Terraform providers | `terraform/provider.tf` + `flake.nix` (languages.terraform.package)  |
| Update Hudu Docker image   | `hosts/hudu/application/docker-image.nix` (hash values)              |
| Manage encrypted secrets   | `.sops.yaml` for rules, `sops <file>` to edit                        |
| Add a NixOS service        | New `.nix` file in `hosts/hudu/`, import in `hosts/hudu/default.nix` |
| Shared host configuration  | `hosts/shared/` — ssh, sops, nix settings, swap, generators          |

## Known TODOs in Code

- `terraform/hudu/vm.tf:1` — Image reference needs runtime update for latest Hudu
- `hosts/hudu/default.nix:46` — Hardcoded IP, should be dynamic from terraform output
- `hosts/hudu/s3.nix:123` — Assert time regex matches current date only
- `hosts/hudu/database.nix:52` — Redis has no password (Hudu limitation)
- `utils/get-wireguard-conf.nu:42` — Endpoint should be dynamic

## Anti-patterns

- Never use `docker` commands or `docker.enable` — Podman only
- Never edit `.pre-commit-config.yaml` directly
- Never commit unencrypted secrets or age private keys
- Never use `as any` / `@ts-ignore` equivalents (suppress type/lint errors)
- Never hardcode IPs when they can come from Terraform/Nix config (existing TODOs are known debt)
- Don't add `statix` or `nil` pre-commit checks until upstream issues are resolved
