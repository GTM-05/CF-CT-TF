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
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "requested_ou" {
  type = string
}

variable "account_id" {
  type        = string
  default     = ""
  description = "Existing account id for adoption. Empty for new-account requests."
}

output "account_id" {
  value = var.account_id
}

output "requested_ou" {
  value = var.requested_ou
}
