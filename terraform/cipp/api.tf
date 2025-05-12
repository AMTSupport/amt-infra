resource "azurerm_service_plan" "service_plan" {
  resource_group_name = azurerm_resource_group.cipp.name
  location            = azurerm_resource_group.cipp.location
  name                = "CIPP-srv-wrcio"
  os_type             = "Windows"
  sku_name            = "Y1"
}

resource "azurerm_app_service_source_control" "cipp-api" {
  app_id   = azurerm_windows_function_app.cipp-api.id
  branch   = "master"
  repo_url = "https://github.com/AMTSupport/CIPP-API"

  github_action_configuration {
    generate_workflow_file = true
  }
}

resource "azurerm_windows_function_app" "cipp-api" {
  resource_group_name = azurerm_resource_group.cipp.name
  location            = azurerm_resource_group.cipp.location
  service_plan_id     = azurerm_service_plan.service_plan.id

  name                       = "cippwrcio"
  storage_account_access_key = azurerm_storage_account.cipp-storage.primary_access_key
  storage_account_name       = azurerm_storage_account.cipp-storage.name
  client_certificate_mode    = "Required"

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  auth_settings_v2 {
    auth_enabled           = true
    require_authentication = true
    unauthenticated_action = "RedirectToLoginPage"

    login {

    }

    azure_static_web_app_v2 {
      client_id = azurerm_static_web_app.cipp_web.default_host_name
    }
  }

  identity {
    type         = "SystemAssigned"
    identity_ids = []
  }

  site_config {
    application_stack {
      powershell_core_version = "7.4"
    }

    use_32_bit_worker = false

    default_documents = [
      "Default.htm",
      "Default.html",
      "Default.asp",
      "index.htm",
      "index.html",
      "iisstart.htm",
      "default.aspx",
      "index.php"
    ]
    ftps_state = "FtpsOnly"
  }
}
