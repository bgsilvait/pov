provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"
}

module "single-account-threat-detection-us-east-1" {
  providers = {
    aws = aws.us-east-1
  }
  source                  = "draios/secure-for-cloud/aws//modules/services/event-bridge"
  target_event_bus_arn    = "arn:aws:events:eu-central-1:[Sysdig AWS Account ID]:event-bus/eu-central-1-production-falco-1"
  trusted_identity        = "arn:aws:iam::[Sysdig AWS Account ID]:role/eu-central-1-production-secure-assume-role"
  external_id             = "[Sysdig External ID]"
  name                    = "sysdig-secure-events-0tla"
  deploy_global_resources = true
}

module "single-account-threat-detection-eu-central-1" {
  providers = {
    aws = aws.eu-central-1
  }
  source               = "draios/secure-for-cloud/aws//modules/services/event-bridge"
  target_event_bus_arn = "arn:aws:events:eu-central-1:[Sysdig AWS Account ID]:event-bus/eu-central-1-production-falco-1"
  trusted_identity     = "arn:aws:iam::[Sysdig AWS Account ID]:role/eu-central-1-production-secure-assume-role"
  external_id          = "[Sysdig External ID]"
  name                 = "sysdig-secure-events-0tla"
  role_arn             = module.single-account-threat-detection-us-east-1.role_arn
}

module "single-account-cspm" {
  providers = {
    aws = aws.us-east-1
  }
  source           = "draios/secure-for-cloud/aws//modules/services/trust-relationship"
  role_name        = "sysdig-secure-2ljs"
  trusted_identity = "arn:aws:iam::[Sysdig Account ID]:role/eu-central-1-production-secure-assume-role"
  external_id      = "[Sysdig External ID]"
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

resource "sysdig_secure_cloud_auth_account" "aws_account_" {
  enabled       = true
  provider_id   = "[Target AWS Account ID]"
  provider_type = "PROVIDER_AWS"

  feature {

    secure_threat_detection {
      enabled    = true
      components = ["COMPONENT_EVENT_BRIDGE/secure-runtime"]
    }

    secure_identity_entitlement {
      enabled    = true
      components = ["COMPONENT_EVENT_BRIDGE/secure-runtime", "COMPONENT_TRUSTED_ROLE/secure-posture"]
    }

    secure_config_posture {
      enabled    = true
      components = ["COMPONENT_TRUSTED_ROLE/secure-posture"]
    }
  }
  component {
    type     = "COMPONENT_TRUSTED_ROLE"
    instance = "secure-posture"
    trusted_role_metadata = jsonencode({
      aws = {
        role_name = "sysdig-secure-2ljs"
      }
    })
  }
  component {
    type     = "COMPONENT_EVENT_BRIDGE"
    instance = "secure-runtime"
    event_bridge_metadata = jsonencode({
      aws = {
        role_name = "sysdig-secure-events-0tla"
        rule_name = "sysdig-secure-events-0tla"
      }
    })
  }
}