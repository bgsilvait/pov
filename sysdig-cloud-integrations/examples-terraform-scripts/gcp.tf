provider "google" {
  project = "[Target GCP Project ID]"
  region  = "[Target GCP Region]"
}

module "project-posture" {
  source               = "sysdiglabs/secure/google//modules/services/service-principal"
  project_id           = "[Target GCP Project ID]"
  service_account_name = "[Service Account Name]"
}

module "single-project-threat-detection" {
  source        = "sysdiglabs/secure/google//modules/services/webhook-datasource"
  project_id    = "[Target GCP Project ID]"
  push_endpoint = "[Sysdig Endpoint]"
  external_id   = "[Sysdig External ID]"
}

module "vm-host-scan" {
	source			= "sysdiglabs/secure/google//modules/services/agentless-scan"
	project_id		= "[Target GCP Project ID]"
	worker_identity	= "agentless-worker-sa@prod-sysdig-agentless.iam.gserviceaccount.com"
	sysdig_backend	= "[Sysdig Backend ID]"
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

resource "sysdig_secure_cloud_auth_account" "gcp_project_[Target GCP Project ID]" {
  enabled       = true
  provider_id   = "[Target GCP Project ID]"
  provider_type = "PROVIDER_GCP"

  feature {

    secure_threat_detection {
      enabled    = true
      components = ["COMPONENT_WEBHOOK_DATASOURCE/secure-runtime"]
    }

    secure_identity_entitlement {
      enabled    = true
      components = ["COMPONENT_WEBHOOK_DATASOURCE/secure-runtime"]
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
          routing_key            = "[Sysdig Routing Key]"
        }
        service_principal = {
          workload_identity_federation = {
            pool_id          = module.single-project-threat-detection.workload_identity_pool_id
            pool_provider_id = module.single-project-threat-detection.workload_identity_pool_provider_id
            project_number   = module.single-project-threat-detection.workload_identity_project_number
          }
          email = module.single-project-threat-detection.service_account_email
        }
      }
    })
  }
  component {
    type     = "COMPONENT_SERVICE_PRINCIPAL"
    instance = "secure-scanning"
    service_principal_metadata = jsonencode({
      gcp = {
        workload_identity_federation = {
          pool_provider_id = module.vm-host-scan.workload_identity_pool_provider
        }
        email = module.vm-host-scan.controller_service_account
      }
    })
  }
  depends_on = [module.project-posture, module.single-project-threat-detection, module.vm-host-scan]
}

