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
      Stack     = "account-resources"
    }
  }
}

provider "aws" {
  alias  = "member"
  region = var.region
  dynamic "assume_role" {
    for_each = var.terraform_role_arn == "" ? [] : [var.terraform_role_arn]
    content {
      role_arn = assume_role.value
    }
  }
}

variable "region" { type = string }
variable "terraform_role_arn" {
  type    = string
  default = ""
}
variable "dry_run" {
  type    = bool
  default = true
}
output "message" {
  value = var.dry_run ? "account-resources stack is a placeholder for extra per-account workloads after baseline." : "ready"
}
