resource "digitalocean_custom_image" "hudu-os-image" {
  name         = "Hudu OS Image"
  distribution = "Unknown OS"
  regions      = ["syd1"]
  url          = "https://nextcloud.racci.dev/s/ZcPtAKgJswzWAom/download"

  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [
      terraform_data.image_version_trigger.output
    ]
  }
}

resource "digitalocean_droplet" "hudu" {
  name   = "Hudu"
  region = "syd1"
  size   = "s-2vcpu-4gb"
  image  = digitalocean_custom_image.hudu-os-image.id

  ssh_keys = [
    digitalocean_ssh_key.James_Work_Key.id
  ]
}
