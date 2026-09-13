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

variable "tags" {
  type    = map(string)
  default = {}
}

variable "kms_key_arn" {
  type     = string
  default  = null
  nullable = true
}

variable "secret_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "ARN of an existing secret. Never pass secret values."
  validation {
    condition     = var.secret_arn == null || startswith(var.secret_arn, "arn:")
    error_message = "secret_arn must be an ARN, never a secret value."
  }
}

variable "directory_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Directory identifier for AD join. Never pass directory passwords."
}

data "aws_iam_policy_document" "ec2_trust" {
  count = var.enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  count              = var.enabled ? 1 : 0
  name               = "valeotf-ec2-baseline"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  count = var.enabled ? 1 : 0
  name  = "valeotf-ec2-baseline"
  role  = aws_iam_role.ec2[0].name
  tags  = var.tags
}

output "instance_profile_name" {
  value = try(aws_iam_instance_profile.ec2[0].name, null)
}

output "instance_profile_arn" {
  value = try(aws_iam_instance_profile.ec2[0].arn, null)
}

output "secret_arn_ref" {
  value       = var.secret_arn
  description = "ARN reference only."
}

output "directory_id" {
  value = var.directory_id
}

output "termination_automation_status" {
  value       = "MANUAL_REVIEW"
  description = "Legacy Lambda/EventBridge termination remains inventoried until imported; this module does not recreate empty SSM documents."
}
