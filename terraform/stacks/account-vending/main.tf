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
      Stack     = "account-vending"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "account_name" {
  type = string
}

variable "account_email" {
  type    = string
  default = ""
}

variable "parent_ou_id" {
  type    = string
  default = ""
}

variable "account_id" {
  type    = string
  default = ""
}

variable "enable_vending" {
  type        = bool
  default     = false
  description = "Create an Organizations account. Keep false until a reviewed plan exists."
}

variable "enroll_if_unenrolled" {
  type    = bool
  default = false
}

variable "required_controls" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "dry_run" {
  type    = bool
  default = true
}

module "vending" {
  source              = "../../modules/account-vending"
  enabled             = var.enable_vending && var.dry_run == false
  account_name        = var.account_name
  account_email       = var.account_email
  parent_ou_id        = var.parent_ou_id
  existing_account_id = var.account_id
  tags                = var.tags
}

module "control_tower" {
  source               = "../../modules/control-tower-adapter"
  enabled              = true
  enroll_if_unenrolled = var.enroll_if_unenrolled
  account_id           = module.vending.account_id
  required_controls    = var.required_controls
}

output "account_id" {
  value = module.vending.account_id
}

output "control_tower_adapter" {
  value = module.control_tower.adapter_contract
}

output "dry_run" {
  value = var.dry_run
}
