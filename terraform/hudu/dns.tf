resource "azurerm_dns_a_record" "hudu" {
  resource_group_name = var.dns_zone.resource_group_name
  zone_name           = var.dns_zone.name

  ttl     = 3600
  name    = "hudu"
  records = [digitalocean_reserved_ip.hudu.ip_address]
}
