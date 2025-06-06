{
  imports = [
    ./nix.nix
    ./sops.nix
    ./ssh.nix
    ./swap.nix
  ];

  services = {
    getty.autologinUser = "root";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVVzqHYt34dMsaFkX3K8m2vtam/RcUHiS00CBtLpolh"
  ];

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      diskSize = 5 * 1024;
    };
  };
}
