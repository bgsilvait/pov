provider "google" {
  project = "[Target GCP Project ID]"
  region  = "us-central1"
}

module "project-posture" {
  source               = "sysdiglabs/secure/google//modules/services/service-principal"
  project_id           = "[Target GCP Project ID]"
  service_account_name = "sysdig-secure-2ljs"
}

module "single-project-threat-detection" {
  source        = "sysdiglabs/secure/google//modules/services/webhook-datasource"
  project_id    = "[Target GCP Project ID]"
  push_endpoint = "[Sysdig Endpoint]"
  external_id   = "[Sysdig External ID]"
}

terraform {

  required_providers {
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~> 1.23.2"
    }
  }
}

provider "sysdig" {
  sysdig_secure_url       = "[Sysdig Endpoint]"
  sysdig_secure_api_token = "[Sysdig API Token]"
}

resource "sysdig_secure_cloud_auth_account" "gcp_project_[Target GCP Project ID]" {
  enabled       = true
  provider_id   = "[Target GCP Project ID]"
  provider_type = "PROVIDER_GCP"

  feature {

    secure_threat_detection {
      enabled    = true
      components = ["COMPONENT_WEBHOOK_DATASOURCE/secure-runtime", "COMPONENT_SERVICE_PRINCIPAL/secure-runtime"]
    }

    secure_identity_entitlement {
      enabled    = true
      components = ["COMPONENT_SERVICE_PRINCIPAL/secure-posture"]
    }

    secure_config_posture {
      enabled    = true
      components = ["COMPONENT_SERVICE_PRINCIPAL/secure-posture"]
    }
  }
  component {
    type     = "COMPONENT_SERVICE_PRINCIPAL"
    instance = "secure-posture"
    service_principal_metadata = jsonencode({
      gcp = {
        key = module.project-posture.service_account_key
      }
    })
  }
  component {
    type     = "COMPONENT_WEBHOOK_DATASOURCE"
    instance = "secure-runtime"
    webhook_datasource_metadata = jsonencode({
      gcp = {
        webhook_datasource = {
          pubsub_topic_name      = module.single-project-threat-detection.ingestion_pubsub_topic_name
          sink_name              = module.single-project-threat-detection.ingestion_sink_name
          push_subscription_name = module.single-project-threat-detection.ingestion_push_subscription_name
          push_endpoint          = module.single-project-threat-detection.push_endpoint
        }
      }
    })
  }
  component {
    type     = "COMPONENT_SERVICE_PRINCIPAL"
    instance = "secure-runtime"
    service_principal_metadata = jsonencode({
      gcp = {
        workload_identity_federation = {
          pool_id          = module.single-project-threat-detection.workload_identity_pool_id
          pool_provider_id = module.single-project-threat-detection.workload_identity_pool_provider_id
          project_number   = module.single-project-threat-detection.workload_identity_project_number
        }
        email = module.single-project-threat-detection.service_account_email
      }
    })
  }
  depends_on = [module.project-posture, module.single-project-threat-detection]
}

