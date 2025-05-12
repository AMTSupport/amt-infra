{
  description = "Infrastructure for AMT";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-root.url = "github:srid/flake-root";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

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

          devenv.shells.default = {
            # Fixes https://github.com/cachix/devenv/issues/528
            containers = lib.mkForce { };

            packages = with pkgs; [
              azure-cli
              terraformer
              git
              age
              sops
              ssh-to-age
              openssh
              caddy
            ];

            languages = {
              nix.enable = true;
              terraform = {
                enable = true;
                package = pkgs.terraform.withPlugins (
                  p: with p; [
                    azurerm
                    sops
                  ]
                );
              };
            };

            pre-commit.hooks = {
              deadnix.enable = true;
              statix.enable = true;
              ripsecrets.enable = true;
              treefmt = {
                enable = true;
                package = config.treefmt.build.wrapper;
              };
            };

            enterShell = ''
              VARIABLES=$(sops exec-file ${./terraform/secrets.yaml} 'cat {} | sed "/^#/d; /^$/d; s/: /=/"')

              if [ $? -ne 0 ]; then
                echo "Failed to read secrets, ensure you have an age key in ~/.config/sops/age/keys.txt"
                exit 1
              fi

              IFS=$'\n' read -r -d ''' -a VARIABLES <<< "$VARIABLES"
              for i in "''${VARIABLES[@]}"; do
                export $i
              done
            '';
          };

          treefmt.config = {
            inherit (config.flake-root) projectRootFile;

            programs = {
              terraform = {
                enable = true;
                inherit (config.devenv.shells.default.languages.terraform) package;
              };
              statix.enable = true;
              prettier.enable = true;
              shellcheck.enable = true;
            };

            settings.global.excludes = [
              ".envrc"
              "terraform/secrets.yaml"
              "terraform/.terraform.lock.hcl"
            ];
          };
        };
    };
}
