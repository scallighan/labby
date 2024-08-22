terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.109.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source = "azure/azapi"
      version = "=1.13.1"
    }
  }
  backend "azurerm" {

  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}


data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
} 

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.loc_for_naming}"
  location = var.location
  tags = local.tags
}

resource "azurerm_virtual_network" "default" {
  name                = "vnet-${local.cluster_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.5.0.0/16"]

  tags = local.tags
}

resource "azurerm_subnet" "cluster" {
  name                 = "subnet-${local.cluster_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.5.5.0/27"]

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  
  }

}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.rg.location
  name                = "uai-${local.cluster_name}"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-${local.cluster_name}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization = true
}

resource "azurerm_role_assignment" "containerapptokv" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_role_assignment" "reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_container_app_environment" "this" {
  name                       = "ace-${local.cluster_name}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.default.id

  infrastructure_subnet_id = azurerm_subnet.cluster.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = local.tags

}

resource "azurerm_container_app" "backend" {
  name                         = "labby-backend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "backend"
      image  = "ghcr.io/scallighan/labby-backend:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_SUBSCRIPTION_ID"
        value = data.azurerm_client_config.current.subscription_id
      }
      env {
        name  = "AZURE_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id

      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.this.client_id
      }
      env {
        name = "AZURE_OPENAI_API_KEY"
        secret_name = "azure-openai-api-key"
      }
      env {
        name = "AZURE_OPENAI_CHAT_DEPLOYMENT_NAME"
        secret_name = "azure-openai-chat-deployment-name"
      }
      env {
        name = "AZURE_OPENAI_ENDPOINT"
        secret_name = "azure-openai-endpoint"
      }
      env {
        name = "AZURE_OPENAI_TEXT_DEPLOYMENT_NAME"
        secret_name = "azure-openai-text-deployment-name"
      }
      env {
        name = "GLOBAL_LLM_SERVICE"
        secret_name = "global-llm-service"
      }
      env {
        name = "TOKEN_LIMIT"
        value = "8192"
      }
    }
    http_scale_rule {
      name                = "http-1"
      concurrent_requests = "100"
    }
    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    transport                  = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name = "microsoft-provider-authentication-secret"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/CLIENT-SECRET"
  }
  secret {
    name = "azure-openai-api-key"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/AZURE-OPENAI-API-KEY"
  }

  secret {
    name = "azure-openai-chat-deployment-name"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/AZURE-OPENAI-CHAT-DEPLOYMENT-NAME"
  }
  secret {
    name = "azure-openai-endpoint"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/AZURE-OPENAI-ENDPOINT"
  }
  secret {
    name = "azure-openai-text-deployment-name"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/AZURE-OPENAI-TEXT-DEPLOYMENT-NAME"
  }
  secret {
    name = "global-llm-service"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/GLOBAL-LLM-SERVICE"
  }   

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

  lifecycle {
    ignore_changes = [ secret ]
  }
}

resource "azurerm_container_app" "frontend" {
  name                         = "labby-frontend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "frontend"
      image  = "ghcr.io/scallighan/labby-frontend:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "API_ENDPOINT"
        value = "${azurerm_container_app.backend.ingress[0].fqdn}"
      }

    }
    http_scale_rule {
      name                = "http-1"
      concurrent_requests = "100"
    }
    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    transport                  = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

  lifecycle {
    ignore_changes = [ secret ]
  }
}


resource "azurerm_container_app" "teamsbot" {
  name                         = "labby-teamsbot"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "teamsbot"
      image  = "ghcr.io/scallighan/labby-teamsbot:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name = "AAD_APP_CLIENT_ID"
        secret_name = "aad-app-client-id"
      }
      env {
        name = "AAD_APP_CLIENT_SECRET"
        secret_name = "aad-app-client-secret"
      }

      env {
        name = "AAD_APP_TENANT_ID"
        secret_name = "aad-app-tenant-id"
      }

      env {
        name = "BOT_DOMAIN"
        secret_name = "bot-domain"
      }

      env {
        name = "BOT_ID"
        secret_name = "bot-id"
      }

      env {
        name = "BOT_PASSWORD"
        secret_name = "bot-password"
      }

      env {
        name = "BACKEND_CLIENT_ID"
        secret_name = "backend-client-id"
      }

      env {
        name = "AAD_APP_OAUTH_AUTHORITY_HOST"
        value = "https://login.microsoftonline.com"
      }

      env {
        name = "RUNNING_ON_AZURE"
        value = "1"
      }

      env {
        name = "BASE_URL"
        value = "https://${azurerm_container_app.backend.ingress[0].fqdn}"
      }
      
     
    }
    http_scale_rule {
      name                = "http-1"
      concurrent_requests = "100"
    }
    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 3978
    transport                  = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name = "aad-app-client-id"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/AAD-APP-CLIENT-ID"
  }
  secret {
    name = "aad-app-client-secret"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/AAD-APP-CLIENT-SECRET"
  }

  secret {
    name = "aad-app-tenant-id"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/AAD-APP-TENANT-ID"
  }
  secret {
    name = "bot-domain"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/BOT-DOMAIN"
  }
  secret {
    name = "bot-id"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/BOT-ID"
  }
  secret {
    name = "bot-password"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/BOT-PASSWORD"
  }

  secret {
    name = "backend-client-id"
    identity = azurerm_user_assigned_identity.this.id
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/VITE-BACKEND-CLIENT-ID"
  }   

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

  lifecycle {
    ignore_changes = [ secret ]
  }
}


resource "azapi_resource" "teamsbot" {
  type = "Microsoft.BotService/botServices@2022-09-15"
  name = "labby-teamsbot-bot"
  location = "global"
  parent_id = azurerm_resource_group.rg.id
  tags = local.tags
  body = jsonencode({
    properties = {
      displayName = "labby-teamsbot-bot"
      endpoint = "https://${azurerm_container_app.teamsbot.ingress[0].fqdn}/api/messages"
      msaAppId = var.bot_id
      msaAppTenantId = var.bot_tenant_id
      msaAppType = "SingleTenant"
    }
    sku = {
      name = "F0"
    }
    kind = "azurebot"
  })
}

resource "azurerm_bot_channel_ms_teams" "this" {
  bot_name            = "labby-teamsbot-bot"
  location            = "global"
  resource_group_name = azurerm_resource_group.rg.name
}