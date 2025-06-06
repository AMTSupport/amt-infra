{
  flake,
  config,
  ...
}:
let
  asGB = size: toString (size * 1024 * 1024 * 1024);
in
{
  nix = {
    channel.enable = false;
    # disable global registry
    settings.flake-registry = "";
    # set system registry
    registry = {
      nixpkgs.to = {
        type = "path";
        path = flake.inputs.nixpkgs;
      };
    };

    # explicitly set nix-path, NIX_PATH to nixpkgs from system registry
    settings.nix-path = [ "nixpkgs=flake:nixpkgs" ];
    nixPath = config.nix.settings.nix-path;

    settings.min-free = asGB 1;
    settings.max-free = asGB 50;
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
  };

  systemd.services.nix-gc.serviceConfig = {
    Restart = "on-failure";
  };
}
