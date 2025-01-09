terraform {
  required_providers {
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~>1.42"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3"
    }
  }
}

provider "sysdig" {
  sysdig_secure_url       = "https://eu1.app.sysdig.com"
  sysdig_secure_api_token = "[Sysdig API Token]"
}

provider "azurerm" {
  features {}
  subscription_id = "[Target Azure Subscription ID]"
  tenant_id       = "[Target Azure Tenant ID]"
}

provider "azuread" {
  tenant_id = "[Target Azure Tenant ID]"
}

module "onboarding" {
  source          = "sysdiglabs/secure/azurerm//modules/onboarding"
  version         = "~>0.3"
  subscription_id = "[Target Azure Subscription ID]"
  tenant_id       = "[Target Azure Tenant ID]"
}

module "config-posture" {
  source                   = "sysdiglabs/secure/azurerm//modules/config-posture"
  version                  = "~>0.3"
  subscription_id          = module.onboarding.subscription_id
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
}

resource "sysdig_secure_cloud_auth_account_feature" "config_posture" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_CONFIG_POSTURE"
  enabled    = true
  components = [module.config-posture.service_principal_component_id]
  depends_on = [module.config-posture]
}
