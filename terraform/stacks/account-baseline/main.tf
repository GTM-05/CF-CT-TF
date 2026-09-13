terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      ManagedBy = "valeotf"
      Stack     = "account-baseline"
    }
  }
}

provider "aws" {
  alias  = "member"
  region = var.region
  default_tags {
    tags = {
      ManagedBy = "valeotf"
      Stack     = "account-baseline"
    }
  }

  dynamic "assume_role" {
    for_each = var.terraform_role_arn == "" ? [] : [var.terraform_role_arn]
    content {
      role_arn     = assume_role.value
      session_name = "valeotf-account-baseline"
      external_id  = var.external_id == "" ? null : var.external_id
    }
  }
}

locals {
  manage_member = var.account_id != "" && var.dry_run == false
  tags = merge(var.tags, {
    ManagedBy   = "valeotf"
    Environment = var.environment
    AccountName = var.account_name
  })
}

module "account" {
  source       = "../../modules/account"
  enabled      = true
  name         = var.account_name
  environment  = var.environment
  requested_ou = var.requested_ou
  account_id   = var.account_id
  tags         = local.tags
}

module "control_tower" {
  source               = "../../modules/control-tower-adapter"
  enabled              = var.enable_control_tower_governance
  enroll_if_unenrolled = var.enroll_if_unenrolled
  account_id           = var.account_id
  required_controls    = var.required_controls
}

module "iam" {
  source                 = "../../modules/iam"
  enabled                = var.enable_iam && local.manage_member
  tags                   = local.tags
  trusted_principal_arns = var.trusted_principal_arns
  external_id            = var.external_id
  providers              = { aws = aws.member }
}

module "kms" {
  source    = "../../modules/kms"
  enabled   = var.enable_kms && local.manage_member
  tags      = local.tags
  providers = { aws = aws.member }
}

module "network" {
  source          = "../../modules/network"
  enabled         = var.enable_network && local.manage_member
  network_profile = var.network_profile
  kms_key_arn     = module.kms.key_arn
  tags            = local.tags
  providers       = { aws = aws.member }
}

module "security" {
  source    = "../../modules/security"
  enabled   = var.enable_encryption && local.manage_member
  tags      = local.tags
  providers = { aws = aws.member }
}

module "ssm" {
  source    = "../../modules/ssm"
  enabled   = var.enable_ssm && local.manage_member
  tags      = local.tags
  providers = { aws = aws.member }
}

module "backup" {
  source      = "../../modules/backup"
  enabled     = var.enable_backup && local.manage_member
  kms_key_arn = module.kms.key_arn
  tags        = local.tags
  providers   = { aws = aws.member }
}

module "monitoring" {
  source      = "../../modules/monitoring"
  enabled     = var.enable_monitoring && local.manage_member
  kms_key_arn = module.kms.key_arn
  tags        = local.tags
  providers   = { aws = aws.member }
}

module "config" {
  source      = "../../modules/config"
  enabled     = var.enable_config && local.manage_member
  kms_key_arn = module.kms.key_arn
  tags        = local.tags
  providers   = { aws = aws.member }
}

module "logging" {
  source      = "../../modules/logging"
  enabled     = var.enable_logging && local.manage_member
  kms_key_arn = module.kms.key_arn
  tags        = local.tags
  providers   = { aws = aws.member }
}

module "ec2_baseline" {
  source      = "../../modules/ec2-baseline"
  enabled     = var.enable_ec2_baseline && local.manage_member
  kms_key_arn = module.kms.key_arn
  tags        = local.tags
  providers   = { aws = aws.member }
}

module "rds_baseline" {
  source      = "../../modules/rds-baseline"
  enabled     = var.enable_rds_baseline && local.manage_member
  kms_key_arn = module.kms.key_arn
  subnet_ids  = module.network.private_subnet_ids
  tags        = local.tags
  providers   = { aws = aws.member }
}

output "control_tower_adapter" {
  value = module.control_tower.adapter_contract
}

output "account_id" {
  value = module.account.account_id
}

output "plan_role_arn" {
  value = module.iam.plan_role_arn
}

output "apply_role_arn" {
  value = module.iam.apply_role_arn
}

output "dry_run" {
  value = var.dry_run
}
