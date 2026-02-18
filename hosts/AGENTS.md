# NixOS Hosts

NixOS configurations for AMT servers. Currently one host (`hudu`) with shared modules.

## Structure

```text
hosts/
  ├── hudu/                    # Primary host — DigitalOcean droplet
  │   ├── default.nix          # Host entry: imports, Podman setup, cloud-init, networking
  │   ├── application/         # Hudu Rails app
  │   │   ├── default.nix      # Podman containers (hudu-app + hudu-worker), Caddy vhost, systemd deps
  │   │   └── docker-image.nix # Image hash for nix-prefetch-docker (update here for new Hudu versions)
  │   ├── proxy.nix            # Caddy reverse proxy — global config, snippets, security rules, CIPP vhost
  │   ├── database.nix         # PostgreSQL 16 + Redis, backup to S3 via s3fs mount
  │   ├── s3.nix               # S3 proxy containers (s3proxy) — Azure Blob → S3-compatible API
  │   ├── wireguard.nix        # WireGuard VPN — auto-discovers users from users/ directory
  │   └── secrets.yaml         # SOPS-encrypted host secrets
  └── shared/                  # Reusable modules imported by all hosts
      ├── default.nix          # Imports all shared modules, root autologin, authorized keys, VM variant
      ├── generators.nix       # nixos-generators — DigitalOcean image format, SSH key bootstrap
      ├── nix.nix              # Nix settings — registry, gc, auto-optimise, channels disabled
      ├── sops.nix             # SOPS-nix — auto-sets defaultSopsFile from host name
      ├── ssh.nix              # SSH — ed25519 only, host public key from flake tree
      └── swap.nix             # zram swap — 100% memory, swappiness 180
```

## Key Patterns

### Flake References

Modules receive `flake` (not `self`) via `specialArgs` and `inputs` as `inputs'` (system-resolved):

```nix
{ flake, config, pkgs, lib, ... }:
```

Use `flake` to reference files in the repo tree: `"${flake}/users"`, `"${flake}/hosts/${config.networking.hostName}/..."`.

### Podman Containers

All containers use `virtualisation.oci-containers` with `backend = "podman"`. Docker is force-disabled:

```nix
virtualisation = {
  docker.enable = lib.mkForce false;
  podman = {
    enable = true;
    dockerSocket.enable = true;
  };
};
```

Container networking uses the `podman` network. Host services (PG, Redis) are reached via `host.containers.internal`.

### SOPS Secrets

Each module declares its secrets in `sops.secrets`. Default sops file is auto-set by `hosts/shared/sops.nix` based on hostname → `hosts/<hostname>/secrets.yaml`.

Secrets ownership pattern for service-specific secrets:

```nix
sops.secrets."PROXY_IPS/CIPP" = {
  owner = config.users.users.caddy.name;
  inherit (config.users.users.caddy) group;
};
```

Cross-file secrets reference user files:

```nix
sops.secrets."${user}/WIREGUARD_PSK" = {
  sopsFile = "${flake}/users/${user}/secrets.yaml";
  key = "WIREGUARD/PRE_SHARED_KEY";
};
```

### Pipe Operators

Used extensively for data transformation:

```nix
builtins.readDir "${flake}/users"
|> builtins.attrNames
|> map (user: { ... })
```

### Caddy Architecture (proxy.nix)

Global config in `services.caddy.globalConfig` — protocol restrictions (h1/h2 only, no h3 due to past error-500 issues), listener wrappers, timeouts.

Reusable snippets in `services.caddy.extraConfig`:

- `(caching)` — static asset cache headers
- `(compression)` — zstd/gzip for content types
- `(init_vars)` — loads proxy IP secrets from SOPS files
- `(trusted_request)` — CEL expression matching VPN + proxy IPs
- `(security)` — bot filtering, path blocking, URL rewrite rules
- `(proxy)` — X-Real-IP header forwarding
- `(error-handler)` — 404 + abort for non-HTML
- `(cors)` — parameterized CORS snippet

Virtual hosts are defined in their respective modules (application/default.nix, s3.nix, proxy.nix) using `services.caddy.virtualHosts."domain".extraConfig`.

### WireGuard Auto-Discovery

`wireguard.nix` reads `users/` directory at build time to generate peers and SOPS secret declarations. Adding a user directory automatically adds them to the VPN config on next rebuild.

### Custom Docker Image (application/)

Hudu image is patched at build time using `pkgs.dockerTools.buildLayeredImage` + `extraCommands` with perl regex replacements. This patches the Rails export job to use `force_path_style: true` for S3 compatibility with s3proxy.

Update process: run `nix run nixpkgs#nix-prefetch-docker -- --image-name "hududocker/hudu"` and update values in `docker-image.nix`.

### Database Backup Chain

PostgreSQL → zstd compressed backup → s3fs mount → s3proxy-backup container → Azure Blob Storage (RAGRS replication). Backup runs daily at `*-*-* 17:00:00` UTC (3 AM Sydney).

## Adding a New Service

1. Create `hosts/hudu/<service>.nix`
1. Add SOPS secrets if needed (declare in module, add to `hosts/hudu/secrets.yaml` via `sops`)
1. Define Podman container in `virtualisation.oci-containers.containers`
1. Add Caddy virtual host via `services.caddy.virtualHosts`
1. Open firewall ports: `networking.firewall.interfaces.podman0.allowedTCPPorts` for container access
1. Import in `hosts/hudu/default.nix`

## srvos Overrides

This project uses srvos (`inputs.srvos.nixosModules.server`, `hardware-digitalocean-droplet`, etc.) which sets opinionated defaults. Some are overridden:

- `docker.enable = lib.mkForce false` (srvos may enable it)
- `boot.initrd.systemd.enable = lib.mkForce false`
- `cloud-init.settings.datasource = lib.mkForce { ConfigDrive = {}; }`

Always use `lib.mkForce` when overriding srvos defaults.

## Anti-patterns

- Never use `docker` commands or enable Docker — Podman only
- Never hardcode the sops file path — use the auto-detection in `shared/sops.nix`
- Never use `${pkg}/bin/name` — use `lib.getExe` or `lib.getExe'`
- Never skip `lib.mkForce` when overriding srvos defaults — they use `mkDefault` internally
- Never reference `self` — use `flake` (passed via specialArgs)
