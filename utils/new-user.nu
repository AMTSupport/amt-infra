#!/usr/bin/env -S nix shell nixpkgs#nushell nixpkgs#sops nixpkgs#wireguard-tools -c nu

use std/log

def main [] {
  let username = (input "Enter username for the new user: ")

  if ($username | is-empty) {
    log error "Username cannot be empty."
    exit 1
  }

  let user_folder = $"users/($username)"
  if ($user_folder | path exists) {
    log error $"User folder already exists: ($user_folder)"
    exit 1
  }

  mkdir $user_folder
  log info $"User folder created: ($user_folder)"

  let wg_private_key = wg genkey
  let wg_public_key = $wg_private_key | wg pubkey
  let wg_preshared_key = wg genpsk
  log info $"Generated WireGuard keys for user: ($username)"

  let number_of_users = (ls users | length)
  let wireguard_ip = $"10.100.0.($number_of_users)/32"
  log info $"Assigned WireGuard IP: ($wireguard_ip)"

$"{
  wireguard = {
    publicKey = \"($wg_public_key)\";
    allowedIPs = [ \"($wireguard_ip)\" ];
  };
}
" | save $"($user_folder)/default.nix"

$"WIREGUARD:
  PRIVATE_KEY: ($wg_private_key)
  PRE_SHARED_KEY: ($wg_preshared_key)" | sops encrypt --filename-override $"($user_folder)/secrets.yaml"  | save $"($user_folder)/secrets.yaml"

  log info $"Secrets saved to: ($user_folder)/secrets.yaml"
  log info $"New user setup complete: ($username)"
}
