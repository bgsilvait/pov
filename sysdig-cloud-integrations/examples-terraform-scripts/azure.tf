provider "azurerm" {
  features { }
  subscription_id = "[Target Azure Subscription ID]"
  tenant_id       = "[Target Azure Tenand ID]"
}

provider "azuread" {
  tenant_id       = "[Target Azure Tenand ID]"
}

module "subscription-posture" {
  source                = "sysdiglabs/secure/azurerm//modules/services/service-principal"
  subscription_id       = "[Target Azure Subscription ID]"
  sysdig_client_id      = "[Sysdig External ID]"
}

module "single-subscription-threat-detection" {
  source               = "sysdiglabs/secure/azurerm//modules/services/event-hub-data-source"
  subscription_id      = "[Target Azure Subscription ID]"
  region               = "[Sysdig Region ID]"
  sysdig_client_id     = "[Sysdig External ID]"
  event_hub_namespace_name = "sysdig-secure-events-kp0i"
  resource_group_name = "sysdig-secure-events-kp0i"
  diagnostic_settings_name = "sysdig-secure-events-kp0i"
}

module "single-account-agentless-scanning" {
  source                       = "sysdiglabs/secure/azurerm//modules/services/host-scanner"
  subscription_id              = "[Target Azure Subscription ID]"
  sysdig_tenant_id             = "[Sysdig Tenant ID]"
  sysdig_service_principal_id  = "[Sysdig Service Principal ID]"
}

terraform {

  required_providers {
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~> 1.24.2"
    }
  }
}

provider "sysdig" {
  sysdig_secure_url       = "[Sysdig Endpoint]"
  sysdig_secure_api_token = "[Sysdig API Token]"
}

resource "sysdig_secure_cloud_auth_account" "azure_subscription_[Target Azure Subscription ID]" {
  enabled       = true
  provider_id   = "[Target Azure Subscription ID]"
  provider_type = "PROVIDER_AZURE"

  feature {

    secure_threat_detection {
      enabled    = true
      components = ["COMPONENT_EVENT_BRIDGE/secure-runtime"]
    }

    secure_config_posture {
      enabled    = true
      components = ["COMPONENT_SERVICE_PRINCIPAL/secure-posture"]
    }

    secure_agentless_scanning {
      enabled    = true
      components = ["COMPONENT_SERVICE_PRINCIPAL/secure-scanning"]
    }
  }
  component {
    type     = "COMPONENT_SERVICE_PRINCIPAL"
    instance = "secure-posture"
    service_principal_metadata = jsonencode({
      azure = {
        active_directory_service_principal= {
          account_enabled           = true
          display_name              = module.subscription-posture.service_principal_display_name
          id                        = module.subscription-posture.service_principal_id
          app_display_name          = module.subscription-posture.service_principal_app_display_name
          app_id                    = module.subscription-posture.service_principal_client_id
          app_owner_organization_id = module.subscription-posture.service_principal_app_owner_organization_id
        }
      }
    })
  }
  component {
    type     = "COMPONENT_EVENT_BRIDGE"
    instance = "secure-runtime"
    event_bridge_metadata = jsonencode({
      azure = {
        event_hub_metadata= {
          event_hub_name      = module.single-subscription-threat-detection.event_hub_name
          event_hub_namespace = module.single-subscription-threat-detection.event_hub_namespace
          consumer_group      = module.single-subscription-threat-detection.consumer_group_name
        }
      }
    })
  }
  component {
    type     = "COMPONENT_SERVICE_PRINCIPAL"
    instance = "secure-scanning"
    service_principal_metadata = jsonencode({
      azure = {
        active_directory_service_principal= {
          account_enabled           = true
          display_name              = module.subscription-posture.service_principal_display_name
          id                        = module.subscription-posture.service_principal_id
          app_display_name          = module.subscription-posture.service_principal_app_display_name
          app_id                    = module.subscription-posture.service_principal_client_id
          app_owner_organization_id = module.subscription-posture.service_principal_app_owner_organization_id
        }
      }
    })
  }
  provider_alias     = module.subscription-posture.subscription_alias
  provider_tenant_id = "[Target Azure Tenand ID]"
  depends_on         = [module.single-account-agentless-scanning, module.single-subscription-threat-detection, module.subscription-posture]
}

