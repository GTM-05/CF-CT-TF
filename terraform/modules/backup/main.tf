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

variable "kms_key_arn" {
  type     = string
  default  = null
  nullable = true
}

data "aws_iam_policy_document" "backup_trust" {
  count = var.enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  count              = var.enabled ? 1 : 0
  name               = "valeotf-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_trust[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_vault" "platform" {
  count         = var.enabled ? 1 : 0
  name          = "valeotf-platform"
  kms_key_arn   = var.kms_key_arn
  force_destroy = false
  tags          = var.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_backup_plan" "platform" {
  count = var.enabled ? 1 : 0
  name  = "valeotf-platform"
  tags  = var.tags

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.platform[0].name
    schedule          = "cron(0 1 * * ? *)"
    lifecycle {
      delete_after = 35
    }
  }
}

resource "aws_backup_selection" "tagged" {
  count        = var.enabled ? 1 : 0
  name         = "valeotf-tagged"
  plan_id      = aws_backup_plan.platform[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "valeotf:backup"
    value = "true"
  }
}

output "vault_name" {
  value = try(aws_backup_vault.platform[0].name, null)
}

output "plan_id" {
  value = try(aws_backup_plan.platform[0].id, null)
}

output "role_arn" {
  value = try(aws_iam_role.backup[0].arn, null)
}
