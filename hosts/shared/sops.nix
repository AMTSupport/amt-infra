{
  flake,
  config,
  lib,
  ...
}:
let
  defaultSopsPath = "${flake}/hosts/${config.networking.hostName}/secrets.yaml";
in
{
  imports = [
    flake.inputs.sops-nix.nixosModules.sops
  ];

  sops.defaultSopsFile = lib.mkIf (builtins.pathExists defaultSopsPath) defaultSopsPath;
}
