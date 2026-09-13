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

variable "trusted_principal_arns" {
  type        = list(string)
  default     = []
  description = "Platform principals allowed to assume member Terraform roles."

  validation {
    condition     = !var.enabled || length(var.trusted_principal_arns) > 0
    error_message = "trusted_principal_arns is required when IAM is enabled."
  }
}

variable "external_id" {
  type      = string
  default   = ""
  sensitive = true
}

data "aws_iam_policy_document" "trust" {
  count = var.enabled ? 1 : 0
  statement {
    sid     = "AllowPlatformAssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = var.trusted_principal_arns
    }
    dynamic "condition" {
      for_each = var.external_id == "" ? [] : [var.external_id]
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [condition.value]
      }
    }
  }
}

resource "aws_iam_role" "plan" {
  count                = var.enabled ? 1 : 0
  name                 = "valeotf-terraform-plan"
  assume_role_policy   = data.aws_iam_policy_document.trust[0].json
  max_session_duration = 3600
  permissions_boundary = aws_iam_policy.boundary[0].arn
  tags                 = merge(var.tags, { valeotf = "plan" })
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.plan[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role" "apply" {
  count                = var.enabled ? 1 : 0
  name                 = "valeotf-terraform-apply"
  assume_role_policy   = data.aws_iam_policy_document.trust[0].json
  max_session_duration = 3600
  permissions_boundary = aws_iam_policy.boundary[0].arn
  tags                 = merge(var.tags, { valeotf = "apply" })
}

output "plan_role_arn" {
  value = try(aws_iam_role.plan[0].arn, null)
}

output "apply_role_arn" {
  value = try(aws_iam_role.apply[0].arn, null)
}

output "terraform_role_arn" {
  value       = try(aws_iam_role.apply[0].arn, null)
  description = "Default member role for apply. Plan jobs must use plan_role_arn."
}
