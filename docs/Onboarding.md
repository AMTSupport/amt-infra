# Onboarding a new User

Use the script `utils/new-user.nu` to onboard a new user. This script will:

- Create a new folder in `users/` with the username
- Generate and securely encrypt wireguard private key & presharedKey in `secrets.yaml`
- Generate and store wireguard public key & peer IP in `default.nix`

They will also need their IP adding to PROXY_IPS in `hosts/hudu/secrets.yaml` and
