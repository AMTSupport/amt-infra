resource "digitalocean_firewall" "hudu" {
  name = "hudu-firewall"

  droplet_ids = [digitalocean_droplet.hudu.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.permitted_ips
  }

  inbound_rule {
    protocol   = "tcp"
    port_range = "80"
  }

  inbound_rule {
    protocol   = "tcp"
    port_range = "443"
  }

  inbound_rule {
    protocol   = "udp"
    port_range = "443"
  }

  inbound_rule {
    protocol   = "udp"
    port_range = "51820"
  }

  outbound_rule {
    protocol              = "tcp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
    port_range            = "all"
  }
  outbound_rule {
    protocol              = "udp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
    port_range            = "all"
  }
}

resource "digitalocean_reserved_ip" "hudu" {
  droplet_id = digitalocean_droplet.hudu.id
  region     = digitalocean_droplet.hudu.region
}
