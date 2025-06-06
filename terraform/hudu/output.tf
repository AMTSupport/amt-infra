output "hudu_ip" {
  depends_on = [digitalocean_reserved_ip.hudu]
  value      = digitalocean_reserved_ip.hudu.ip_address
  sensitive  = true
}
