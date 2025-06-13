#!/usr/bin/env -S nix shell nixpkgs#nushell nixpkgs#qrencode nixpkgs#wireguard-tools --command nu

def get_flake_value [
  git_root: string,
  attr_path: string,
  apply?: string = "(x: x)"
] {
  return (nix eval --quiet --accept-flake-config --raw $".#nixosConfigurations.hudu.config.($attr_path)" --apply $apply) e> /dev/null
}

def get_nix_value [
  file: string,
  attr_path: string
  apply?: string = "(x: x)"
] {
  return (nix eval --quiet --raw --no-pure-eval --expr $"
  \(import \"($file)\"\).($attr_path)
  " --apply $apply) e> /dev/null
}

def main [
  --qr
] {
  let git_root = git rev-parse --show-toplevel | str trim
  let users = ls $"($git_root)/users" | where type == "dir" | get name | each {|user|
    $user | split row '/' | last
  }

  let selected_user = if ($users | length ) > 1 {
    $users | input list -f
  } else {
    $users | first
  }

  let user_dir = $"($git_root)/users/($selected_user)"
  let address = get_nix_value $user_dir "wireguard.allowedIPs" "builtins.head"
  let public_key = get_nix_value $user_dir "wireguard.publicKey"
  let secret_file = $"($user_dir)/secrets.yaml"
  let preshared_key = sops decrypt --extract "[\"WIREGUARD\"][\"PRE_SHARED_KEY\"]" $secret_file
  let private_key = sops decrypt --extract "[\"WIREGUARD\"][\"PRIVATE_KEY\"]" $secret_file

  # TODO dynamic
  let hudu_endpoint = get_flake_value $git_root "virtualisation.oci-containers.containers.hudu-app.environment.DOMAIN"
  let wg_port = get_flake_value $git_root "networking.wireguard.interfaces.wg0.listenPort"
  let endpoint = "hudu.amt.com.au:51820"
  let gateway = get_flake_value $git_root "networking.wireguard.interfaces.wg0.ips" "builtins.head" | split row '/' | first
  let public_key = sops decrypt --extract "[\"WIREGUARD_PRIVATE_KEY\"]" hosts/hudu/secrets.yaml | wg pubkey

  let conf = $'
[Interface]
Address = ($address)
PrivateKey = ($private_key)
ListenPort = 51820
DNS = ($gateway)

[Peer]
PublicKey = ($public_key)
PresharedKey = ($preshared_key)
Endpoint = ($endpoint)
AllowedIPs = ($gateway)/32
  '

  if $qr {
    $conf | qrencode -t ansiutf8
  } else {
    print --no-newline $conf
  }
}
