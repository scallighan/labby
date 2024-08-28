data "azuread_client_config" "current" {}

resource "azuread_application" "labby-backend" {
  display_name = "labby-backend"
  owners       = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  api {
    oauth2_permission_scope {
      id = random_uuid.labby-teamsbot-backend-apis_chat.result
      admin_consent_description = "Apis.Chat"
      admin_consent_display_name = "Apis.Chat"
      user_consent_display_name = "Apis.Chat"
      user_consent_description = "Apis.Chat"
      enabled = true
      type = "User"
      value = "Apis.Chat"      
    }
  }
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

}

resource "azuread_application" "labby-frontend" {
  display_name = "labby-frontend"
  owners       = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg" 

  required_resource_access {
    resource_app_id = azuread_application.labby-backend.application_id

    resource_access {
      id   = random_uuid.labby-teamsbot-backend-apis_chat.result
      type = "Scope"
    }
  }
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  single_page_application {
    redirect_uris = ["http://localhost:5173/", "http://localhost:5137/", "https://${azurerm_container_app.frontend.ingress[0].fqdn}/"]
  }
}

resource "azuread_application" "labby-teamsbot-aca" {
  display_name = "labby-teamsbot-aca"
  owners       = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"
  identifier_uris = ["api://botid-${azuread_application.labby-teamsbot-bot.application_id}"]

  api {
    oauth2_permission_scope {
      id = random_uuid.labby-teamsbot-aca-access_as_user.result
      admin_consent_description = "Allows Teams to call the app's web APIs as the current user."
      admin_consent_display_name = "Teams can access app's web APIs"
      user_consent_display_name = "Teams can access app's web APIs and make requests on your behalf"
      user_consent_description = "Enable Teams to call this app's web APIs with the same rights that you have"
      enabled = true
      type = "User"
      value = "access_as_user"      
    }
  }

  required_resource_access {
    resource_app_id = azuread_application.labby-backend.application_id

    resource_access {
      id   = random_uuid.labby-teamsbot-backend-apis_chat.result
      type = "Scope"
    }
  }
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }
}


resource "azuread_application_pre_authorized" "teamsbot-aca-1fec8e78-bce4-4aaf-ab1b-5451cc387264" {
    application_id = azuread_application.labby-teamsbot-aca.id
    authorized_client_id = "1fec8e78-bce4-4aaf-ab1b-5451cc387264"

    permission_ids = [
        random_uuid.labby-teamsbot-aca-access_as_user.result
    ]
}

resource "azuread_application_pre_authorized" "teamsbot-aca-5e3ce6c0-2b1f-4285-8d4b-75ee78787346" {
    application_id = azuread_application.labby-teamsbot-aca.id
    authorized_client_id = "5e3ce6c0-2b1f-4285-8d4b-75ee78787346"

    permission_ids = [
        random_uuid.labby-teamsbot-aca-access_as_user.result
    ]
}

resource "azuread_application_pre_authorized" "teamsbot-aca-d3590ed6-52b3-4102-aeff-aad2292ab01c" {
    application_id = azuread_application.labby-teamsbot-aca.id
    authorized_client_id = "d3590ed6-52b3-4102-aeff-aad2292ab01c"

    permission_ids = [
        random_uuid.labby-teamsbot-aca-access_as_user.result
    ]
}

resource "azuread_application_pre_authorized" "teamsbot-aca-00000002-0000-0ff1-ce00-000000000000" {
    application_id = azuread_application.labby-teamsbot-aca.id
    authorized_client_id = "00000002-0000-0ff1-ce00-000000000000"

    permission_ids = [
        random_uuid.labby-teamsbot-aca-access_as_user.result
    ]
}

resource "azuread_application_pre_authorized" "teamsbot-aca-bc59ab01-8403-45c6-8796-ac3ef710b3e3" {
    application_id = azuread_application.labby-teamsbot-aca.id
    authorized_client_id = "bc59ab01-8403-45c6-8796-ac3ef710b3e3"

    permission_ids = [
        random_uuid.labby-teamsbot-aca-access_as_user.result
    ]
}

resource "azuread_application_pre_authorized" "teamsbot-aca-0ec893e0-5785-4de6-99da-4ed124e5296c" {
    application_id = azuread_application.labby-teamsbot-aca.id
    authorized_client_id = "0ec893e0-5785-4de6-99da-4ed124e5296c"

    permission_ids = [
        random_uuid.labby-teamsbot-aca-access_as_user.result
    ]
}

resource "azuread_application_pre_authorized" "teamsbot-aca-4765445b-32c6-49b0-83e6-1d93765276ca" {
    application_id = azuread_application.labby-teamsbot-aca.id
    authorized_client_id = "4765445b-32c6-49b0-83e6-1d93765276ca"

    permission_ids = [
        random_uuid.labby-teamsbot-aca-access_as_user.result
    ]
}

resource "azuread_application_pre_authorized" "teamsbot-aca-4345a7b9-9a63-4910-a426-35363201d503" {
    application_id = azuread_application.labby-teamsbot-aca.id
    authorized_client_id = "4345a7b9-9a63-4910-a426-35363201d503"

    permission_ids = [
        random_uuid.labby-teamsbot-aca-access_as_user.result
    ]
}

resource "azuread_application" "labby-teamsbot-bot" {
  display_name = "labby-teamsbot-bot"
  owners       = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"
}

resource "random_uuid" "labby-teamsbot-aca-access_as_user" {}

resource "random_uuid" "labby-teamsbot-backend-apis_chat" {}