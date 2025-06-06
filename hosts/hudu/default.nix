{
  lib,
  ...
}:
{
  imports = [
    ../shared

    ./application
    ./database.nix
    ./proxy.nix
    ./s3.nix
    ./wireguard.nix
  ];

  users.allowNoPasswordLogin = true;
  boot.initrd.systemd.enable = lib.mkForce false;

  virtualisation = {
    docker.enable = lib.mkForce false;
    podman = {
      enable = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dnsname.enable = false;
    };
  };

  services.cloud-init = {
    enable = true;
    network.enable = false;
    settings = {
      datasource = lib.mkForce {
        ConfigDrive = { };
      };
      datasource_list = lib.mkForce [
        "DigitalOcean"
        "ConfigDrive"
        "NoCloud"
        "None"
      ];
    };
  };

  networking.hostName = "hudu";
  system.stateVersion = "25.05";
}
