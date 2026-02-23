{
  description = "Infrastructure for AMT";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://devenv.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sops-nix.url = "github:Mic92/sops-nix";
    srvos.url = "github:nix-community/srvos";
    nixos-generators.url = "github:nix-community/nixos-generators";

    # Flake & DevShell
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # Inputs & Boring Stuff
    srvos.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.inputs.nixpkgs.follows = "";
    nixos-generators.inputs.nixlib.follows = "nixpkgs";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    devenv.inputs.cachix.follows = "";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, ... }:
      {
        debug = true;

        imports = [
          inputs.devenv.flakeModule
          inputs.treefmt-nix.flakeModule
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        flake = {
          nixosConfigurations.hudu = withSystem "x86_64-linux" (
            { inputs', system, ... }:
            inputs.nixpkgs.lib.nixosSystem {
              inherit system;
              pkgs = import inputs.nixpkgs { inherit system; };

              specialArgs = {
                flake = self;
                inputs = inputs';
              };

              modules = [
                # Compatibility shim for systemd.settings (available in newer nixpkgs
                # but not in nixos-25.05). Needed by the latest srvos which uses
                # systemd.settings.Manager for watchdog configuration.
                (
                  { config, lib, ... }:
                  {
                    options.systemd.settings = lib.mkOption {
                      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
                      default = { };
                    };
                    config = lib.mkIf (config.systemd.settings != { }) {
                      systemd.extraConfig = lib.concatStringsSep "\n" (
                        lib.concatLists (
                          lib.mapAttrsToList (
                            _section: values: lib.mapAttrsToList (key: value: "${key}=${value}") values
                          ) config.systemd.settings
                        )
                      );
                    };
                  }
                )

                inputs.srvos.nixosModules.server
                inputs.srvos.nixosModules.hardware-digitalocean-droplet
                inputs.srvos.nixosModules.mixins-trusted-nix-caches
                inputs.srvos.nixosModules.mixins-nix-experimental

                ./hosts/hudu
              ];
            }
          );
        };

        perSystem =
          {
            config,
            system,
            pkgs,
            lib,
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              config = {
                allowUnfreePredicate = pkg: pkg.pname == "terraform";
              };
            };

            treefmt = {
              projectRootFile = ".git/config";

              programs = {
                terraform = {
                  enable = true;
                  inherit (config.devenv.shells.default.languages.terraform) package;
                };
                actionlint.enable = true;
                deadnix.enable = true;
                hclfmt.enable = true;
                mdformat.enable = true;
                mdsh.enable = true;
                nixf-diagnose = {
                  enable = true;
                  # Newer treefmt-nix passes --auto-fix by default, but nixf-diagnose
                  # in nixos-25.05 doesn't support this flag yet.
                  autoFix = false;
                };
                nixfmt = {
                  enable = true;
                  # Newer treefmt-nix changed from nixfmt-rfc-style to nixfmt (classic),
                  # which doesn't support the pipe operator |> used in this codebase.
                  package = pkgs.nixfmt-rfc-style;
                };
                prettier.enable = true;
                shellcheck.enable = true;
                # Disabled until https://github.com/oppiliappan/statix/issues/88 is resolved
                statix.enable = false;
              };

              settings.global.excludes = [
                ".envrc"
                "**/secrets.yaml"
                "**/ssh_host_ed25519_key.pub"
                "terraform/secrets.yaml"
                "terraform/.terraform.lock.hcl"
              ];
            };

            devenv.shells.default = {
              # Fixes https://github.com/cachix/devenv/issues/528
              containers = lib.mkForce { };

              packages =
                with pkgs;
                [
                  age
                  azure-cli
                  caddy
                  dive
                  git
                  openssh
                  sops
                  ssh-to-age
                  wireguard-tools

                  # Nix tools
                  nil
                  nix-tree
                ]
                ++ (builtins.attrValues config.treefmt.build.programs);

              languages = {
                terraform = {
                  enable = true;
                  package = pkgs.terraform.withPlugins (
                    p: with p; [
                      azurerm
                      sops
                      digitalocean
                    ]
                  );
                };
              };

              git-hooks = {
                # Newer devenv defaults to pkgs.prek which isn't available in nixos-25.05
                package = pkgs.pre-commit;
                hooks = {
                check-added-large-files.enable = true;
                check-case-conflicts.enable = true;
                check-executables-have-shebangs.enable = true;
                check-merge-conflicts.enable = true;
                check-shebang-scripts-are-executable.enable = true;
                detect-private-keys = {
                  enable = true;
                  # Tiggered by the SSH format help message.
                  excludes = [ "hosts/shared/generators.nix" ];
                };
                fix-byte-order-marker.enable = true;
                mixed-line-endings.enable = true;
                # Disabled until a new release that supports pipe-operators hits on the nixpkgs stable branch
                nil.enable = false;
                ripsecrets = {
                  enable = true;
                  excludes = [ "users/.+/default.nix" ];
                };
                trim-trailing-whitespace.enable = true;
                treefmt = {
                  enable = true;
                  package = config.treefmt.build.wrapper;
                };
                };
              };
            };
      }
    );
}
