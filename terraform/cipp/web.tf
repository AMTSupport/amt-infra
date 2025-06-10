resource "azurerm_static_web_app" "cipp_web" {
  resource_group_name = azurerm_resource_group.cipp.name
  name                = "cipp-swa-wrcio"
  location            = "centralus"

  sku_tier = "Standard"
  sku_size = "Standard"

  lifecycle {
    ignore_changes = [
      repository_branch,
      repository_url
    ]
  }
}

resource "azurerm_static_web_app_custom_domain" "amt_domain" {
  static_web_app_id = azurerm_static_web_app.cipp_web.id
  domain_name       = "cipp.amt.com.au"
  validation_type   = "dns-txt-token"
}

resource "azurerm_static_web_app_function_app_registration" "cipp" {
  static_web_app_id = azurerm_static_web_app.cipp_web.id
  function_app_id   = azurerm_windows_function_app.cipp-api.id
}
