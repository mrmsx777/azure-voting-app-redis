locals {
  appservice_plan_sku = "B1"
  redis_sku_name      = "Basic"
  redis_capacity      = 0     # C0
}


resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Application Insights (classic) #azurerm_application_insights
resource "azurerm_application_insights" "ai" {
  name                = "${var.app_name}-ai"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  application_type   = "web"
}

# Redis Cache
resource "azurerm_redis_cache" "redis" {
  name                = "${var.app_name}-redis"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  capacity            = local.redis_capacity
  family              = "C"
  sku_name            = local.redis_sku_name

  non_ssl_port_enabled = false
}

# App Service Plan (Linux)
data "azurerm_service_plan" "plan" {
  name                = "gh-vote-plan"
  resource_group_name = azurerm_resource_group.rg.name
}


############################################################


resource "azurerm_user_assigned_identity" "web_uami" {
  name                = "${var.app_name}-uami"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Read ACR admin creds (enabled earlier)
data "azurerm_container_registry" "acr" {
  name                = replace(var.acr_login_server, ".azurecr.io", "")
  resource_group_name = "rg-platform-shared"
}

resource "azurerm_role_assignment" "acr_pull_uami" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.web_uami.principal_id
}


############################################################


# Web App for Containers (Linux)

resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = data.azurerm_service_plan.plan.id

  https_only          = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.web_uami.id]
  }

  site_config {
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.web_uami.client_id
    application_stack {
      docker_image     = "${var.acr_login_server}/voteapp"
      docker_image_tag = var.image_tag
    }

    # For labs we use registry credentials (from ACR admin)
    # You can migrate to managed identity ACR pull later.
  }

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE       = "false"
    WEBSITES_PORT                             = "80"

    # ACR registry auth (lab-friendly)
    DOCKER_REGISTRY_SERVER_URL                = "https://${var.acr_login_server}"

    
    # Redis connection
    REDIS_HOST                                = azurerm_redis_cache.redis.hostname
    REDIS_PORT                                = tostring(azurerm_redis_cache.redis.ssl_port)
    REDIS_PASSWORD                            = azurerm_redis_cache.redis.primary_access_key

    # App Insights
    APPLICATIONINSIGHTS_CONNECTION_STRING     = azurerm_application_insights.ai.connection_string
    APPINSIGHTS_INSTRUMENTATIONKEY            = azurerm_application_insights.ai.instrumentation_key
  }
  depends_on = [azurerm_role_assignment.acr_pull_uami]
}


output "default_hostname" {
  value = azurerm_linux_web_app.app.default_hostname
}
