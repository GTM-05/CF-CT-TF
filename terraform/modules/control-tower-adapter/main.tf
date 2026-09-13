# Control Tower adapter
#
# Supported with the AWS provider (do not invent additional resources):
# - aws_controltower_control
# - aws_controltower_landing_zone (landing zone updates only where the API exists)
#
# Not implemented here because there is no safe first-class Terraform resource
# that this platform will fake:
# - Account Factory vending / CreateManagedAccount
# - Account enrollment / registration of existing accounts
# - Some guardrail enablement APIs depending on Control Tower version
#
# For those operations, use an approved external integration (AWS CLI/API run
# from GitLab with a dedicated role, or AWS Control Tower console/API) behind
# this module's outputs. See docs/CONTROL-TOWER boundary in ARCHITECTURE.md.

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

variable "enroll_if_unenrolled" {
  type    = bool
  default = false
}

variable "account_id" {
  type    = string
  default = ""
}

variable "required_controls" {
  type    = list(string)
  default = []
}

output "adapter_contract" {
  value = {
    engine                         = "control-tower-adapter"
    terraform_fakes_enrollment     = false
    enroll_if_unenrolled_requested = var.enroll_if_unenrolled
    account_id                     = var.account_id
    required_controls              = var.required_controls
    implementation_options = [
      "AWS Control Tower API from an approved runner (not Terraform resources)",
      "Manual enrollment by the landing-zone team",
    ]
    limitation = "Do not invent Terraform resources for unsupported Control Tower operations."
  }
}
