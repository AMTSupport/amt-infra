{
  flake,
  config,
  pkgs,
  lib,
  ...
}:
let
  users = builtins.readDir "${flake}/users" |> builtins.attrNames;
in
{
  sops.secrets =
    {
      WIREGUARD_PRIVATE_KEY = { };
    }
    // (
      users
      |> builtins.map (
        user:
        lib.nameValuePair "${user}/WIREGUARD_PSK" {
          sopsFile = "${flake}/users/${user}/secrets.yaml";
          key = "WIREGUARD/PRE_SHARED_KEY";
        }
      )
      |> builtins.listToAttrs
    );

  services = {
    resolved = {
      enable = true;
      dnssec = "false";
      llmnr = "false";
      extraConfig = ''
        [Resolve]
        DNSStubListener=no
        ReadEtcHosts=yes
      '';
    };

    dnsmasq = {
      enable = true;
      package = pkgs.dnsmasq;

      settings = {
        interface = "wg0";
        address =
          config.services.caddy.virtualHosts
          |> builtins.attrNames
          |> map (hostName: "/${hostName}/10.100.0.1");
      };
    };
  };

  systemd.network = {
    networks.wg0 = {
      networkConfig = {
        # IPv4Forwarding = true;
      };
    };
  };

  networking = {
    firewall = {
      allowedUDPPorts = [ config.networking.wireguard.interfaces.wg0.listenPort ];

      interfaces.wg0 = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };
    };

    nat = {
      enable = true;
      externalInterface = "ens3";
      internalInterfaces = [ "wg0" ];
    };

    wireguard = {
      enable = true;
      interfaces.wg0 = {
        ips = [ "10.100.0.1/24" ];
        listenPort = 51820;
        privateKeyFile = config.sops.secrets.WIREGUARD_PRIVATE_KEY.path;

        peers =
          builtins.readDir "${flake}/users"
          |> builtins.attrNames
          |> map (user: {
            inherit ((import "${flake}/users/${user}").wireguard) publicKey allowedIPs;
            name = user;
            presharedKeyFile = config.sops.secrets."${user}/WIREGUARD_PSK".path;
          });
      };
    };
  };
}
