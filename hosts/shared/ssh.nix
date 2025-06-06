{
  flake,
  config,
  pkgs,
  ...
}:
let
  # We read & write a package to ensure that the file exists during the build
  hostPublicKey = pkgs.writeTextFile {
    name = "${config.networking.hostName}_ed25519.pub";
    text = builtins.readFile (
      builtins.toPath "${flake}/hosts/${config.networking.hostName}/ssh_host_ed25519_key.pub"
    );
  };
in
{
  users.users.root = {
    openssh.authorizedKeys = {
      keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVVzqHYt34dMsaFkX3K8m2vtam/RcUHiS00CBtLpolh" ];
      keyFiles = [ hostPublicKey ];
    };
  };

  programs.ssh = {
    hostKeyAlgorithms = [ "ssh-ed25519" ];
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];
  };

  environment.etc = {
    "ssh/ssh_host_ed25519_key.pub".source = hostPublicKey;
  };
}
