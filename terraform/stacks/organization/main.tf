terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      ManagedBy = "valeotf"
      Stack     = "organization"
    }
  }
}

provider "tls" {}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "enable_scp" {
  type    = bool
  default = false
}

variable "scp_target_ids" {
  type    = list(string)
  default = []
}

variable "enable_gitlab_oidc" {
  type    = bool
  default = false
}

variable "gitlab_url" {
  type    = string
  default = "https://gitlab.com"
}

module "deny_unapproved_regions" {
  source     = "../../modules/organizations-scp"
  enabled    = var.enable_scp
  name       = "valeotf-deny-unapproved-regions"
  target_ids = var.scp_target_ids
  content    = file("${path.module}/../../../policies/governance/scp-deny-unapproved-regions.json")
}

module "gitlab_oidc" {
  source     = "../../modules/gitlab-oidc"
  enabled    = var.enable_gitlab_oidc
  gitlab_url = var.gitlab_url
}

output "scp_policy_id" {
  value = module.deny_unapproved_regions.policy_id
}
