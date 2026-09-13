terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

variable "enabled" {
  type    = bool
  default = false
}

variable "account_name" {
  type = string
}

variable "account_email" {
  type        = string
  default     = ""
  description = "Required when creating a new account."
}

variable "parent_ou_id" {
  type        = string
  default     = ""
  description = "AWS OU id (ou-xxxx). Logical requested_ou is mapped outside Terraform."
}

variable "existing_account_id" {
  type    = string
  default = ""
}

variable "iam_user_access_to_billing" {
  type    = string
  default = "DENY"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_organizations_account" "this" {
  count                      = var.enabled && var.existing_account_id == "" ? 1 : 0
  name                       = var.account_name
  email                      = var.account_email
  parent_id                  = var.parent_ou_id == "" ? null : var.parent_ou_id
  iam_user_access_to_billing = var.iam_user_access_to_billing
  role_name                  = "OrganizationAccountAccessRole"
  close_on_deletion          = false
  tags                       = var.tags

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.account_email != ""
      error_message = "account_email is required to vend a new account."
    }
  }
}

output "account_id" {
  value = coalesce(var.existing_account_id, try(aws_organizations_account.this[0].id, ""))
}

output "created" {
  value = var.enabled && var.existing_account_id == ""
}
