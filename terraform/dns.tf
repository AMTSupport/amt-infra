locals {
  services = {
    zendesk = {
      CNAME = merge({
        "zendesk1._domainkey" = "zendesk1._domainkey.zendesk.com"
        "zendesk2._domainkey" = "zendesk2._domainkey.zendesk.com"
        "support"             = "amt.zendesk.com"
        }, [for i in range(1, 5) : {
          "zendesk${i}" = "mail${i}.zendesk.com"
      }]...)

      TXT = {
        "zendeskverification" = "04b409d140118af9"
      }
    }

    synergy = {
      TXT = {
        "synergywholesale._domainkey"    = "v=DKIM1; k=rsa; h=sha256; t=s; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA34rMqmkfanv0y8jLKHXqyjmG4n/A1U/6DK7hZuprcXmkl0x+fU7lFLp09EdDFTSxM3eWegIn4cOdqnoaI8BAhWiNmo67h+hsv0Lc6vyYOEnIBEJfBO71FH/UnTak9HmKr2M99Ov69bgqBruVoKYtUtg8FLH9kR9eOxxYz3bvij9uL0ekHWle7VeVkbkWMy+IlvCk5ma2PXEkC1NNXrA46lHGIvQBLdtMfRgZh0LhXQEsGug771GIx4roYYMPNgpagPc+5jDzRjc3sR4HMWEvjiOlWpzhbPX2nEUoi21UEgFqfCwzp8SZAggXc64WvAvL8HThMn9Sdy/X9kQIl4xYeQIDAQAB"
        "synergywholesale._verification" = "347382a3fbed6f8fb92615c43a1fa71db13389725cc0efde3e39988441038a9d"
        "domains"                        = "interface.synergywholesale.com"
      }
    }

    smtp2go = {
      CNAME = {
        "s131192._domainkey" = "dkim.smtp2go.net"
        "link"               = "track.smtp2go.net"
        "em131192"           = "return.smtp2go.net"
      }
    }

    dmarc = {
      TXT = {
        "_dmarc" = "v=DMARC1; p=quarantine; pct=100; rua=mailto:re+ba5b70403d06@inbound.dmarcdigests.com;"
      }
    }

    google = {
      TXT = {
        "@" = "google-site-verification=v1cczoUzMnVSzB1Z_jH_FoVy0PZtOBy7OaoheyRMlvo"
      }
    }

    website = {
      A = {
        "@" = "110.232.143.39"
      }
      CNAME = {
        "www" = "amt.com.au"
      }
    }

    it-quoter = {
      CNAME = {
        "d4lcbtqynjrhez6hjt5ffwvv4fyuwbth._domainkey" = "d4lcbtqynjrhez6hjt5ffwvv4fyuwbth.dkim.amazonses.com"
        "si6waylre2mkkey6gmkivs67iszmewxh._domainkey" = "si6waylre2mkkey6gmkivs67iszmewxh.dkim.amazonses.com"
        "vjkfiyc2nvsz2syqfiodgxrasgs2wsom._domainkey" = "vjkfiyc2nvsz2syqfiodgxrasgs2wsom.dkim.amazonses.com"
      }
    }

    github = {
      TXT = {
        "_gh-amtsupport-o" = "e246e2a5a0"
      }
    }

    nable = {
      CNAME = {
        "dashboard" = "dashboard.system-monitor.com"
      }
    }

    office365 = {
      TXT = {
        "@" = "v=spf1 include:spf.protection.outlook.com -all"
      }

      MX = {
        "@" = {
          preference = 0
          exchange   = "amt-com-au.mail.protection.outlook.com"
        }
      }

      SRV = {
        "_sip._tls" = {
          priority = 100
          weight   = 1
          port     = 443
          target   = "sipdir.online.lync.com"
        }
        "_sipfederationtls._tcp" = {
          priority = 100
          weight   = 1
          port     = 5061
          target   = "sipfed.online.lync.com"
        }
      }

      CNAME = merge({
        "autodiscover" = "autodiscover.outlook.com"
        "sip"          = "sipdir.online.lync.com"
        "lyncdiscover" = "webdir.online.lync.com"
        "msoid"        = "clientconfig.microsoftonline-p.net"
        "outlook"      = "mail.office365.com"

        "enterpriseregistration" = "enterpriseregistration.windows.net"
        "enterpriseenrollment"   = "enterpriseenrollment.manage.microsoft.com"
        }, [for i in range(1, 2) : {
          "selector${i}._domainkey" = "selector${i}-amt-com-au._domainkey.APPLIEDMARKETINGTECH.onmicrosoft.com"
      }]...)
    }
  }

  SPFIncludes = [
    "spf.protection.outlook.com",
    "mail.zendesk.com",
    "spf.smtp2go.com",
    "spf.synergywholesale.com",
    "spf.mspmanager.com"
  ]
}

module "deepmerge" {
  source  = "Invicton-Labs/deepmerge/null"
  version = "0.1.6"
  maps    = values(local.services)
}

resource "azurerm_dns_zone" "amt_root" {
  name                = "amt.com.au"
  resource_group_name = azurerm_resource_group.terraform.name
}

resource "azurerm_dns_txt_record" "spf_record" {
  name                = "@"
  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 3600

  record {
    value = "v=spf1 include:${join(" include:", local.SPFIncludes)} ~all"
  }
}

resource "azurerm_dns_a_record" "records" {
  for_each = try(module.deepmerge.merged.A, {})

  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 3600

  name = each.key
  records = try(
    [tostring(each.value)],
    tolist(each.value),
  )
}

resource "azurerm_dns_aaaa_record" "records" {
  for_each = try(module.deepmerge.merged.AAAA, {})

  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 3600

  name = each.key
  records = try(
    [tostring(each.key)],
    tolist(each.value),
  )
}

resource "azurerm_dns_mx_record" "records" {
  for_each = try(module.deepmerge.merged.MX, {})

  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 3600

  name = each.key
  record {
    preference = each.value.preference
    exchange   = each.value.exchange
  }
}

resource "azurerm_dns_cname_record" "records" {
  for_each = try(module.deepmerge.merged.CNAME, {})

  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 3600

  name   = each.key
  record = each.value
}

resource "azurerm_dns_ns_record" "records" {
  for_each = try(module.deepmerge.merged.NS, {})

  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 3600

  name = each.key
  records = try(
    [tostring(each.key)],
    tolist(each.value),
  )
}

resource "azurerm_dns_ptr_record" "records" {
  for_each = try(module.deepmerge.merged.PTR, {})

  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 3600

  name = each.key
  records = try(
    [tostring(each.key)],
    tolist(each.value),
  )
}

resource "azurerm_dns_srv_record" "records" {
  for_each = try(module.deepmerge.merged.SRV, {})

  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 1800

  name = each.key
  record {
    priority = each.value.priority
    weight   = each.value.weight
    port     = each.value.port
    target   = each.value.target
  }
}

resource "azurerm_dns_txt_record" "records" {
  for_each = try(module.deepmerge.merged.TXT, {})

  resource_group_name = azurerm_resource_group.terraform.name
  zone_name           = azurerm_dns_zone.amt_root.name
  ttl                 = 3600

  name = each.key
  record {
    value = each.value
  }
}
