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

variable "instance_profile_name" {
  type     = string
  default  = null
  nullable = true
}

resource "aws_ssm_association" "update_agent" {
  count            = var.enabled ? 1 : 0
  name             = "AWS-UpdateSSMAgent"
  association_name = "valeotf-update-ssm-agent"
  targets {
    key    = "InstanceIds"
    values = ["*"]
  }
  schedule_expression = "rate(7 days)"
}

resource "aws_ssm_parameter" "baseline_marker" {
  count = var.enabled ? 1 : 0
  name  = "/valeotf/baseline/ssm"
  type  = "String"
  value = "enabled"
  tags  = var.tags
}

output "association_id" {
  value = try(aws_ssm_association.update_agent[0].association_id, null)
}

output "parameter_name" {
  value = try(aws_ssm_parameter.baseline_marker[0].name, null)
}
