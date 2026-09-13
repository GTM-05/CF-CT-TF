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

variable "alias" {
  type    = string
  default = "alias/valeotf-platform"
}

data "aws_caller_identity" "current" {
  count = var.enabled ? 1 : 0
}

data "aws_partition" "current" {
  count = var.enabled ? 1 : 0
}

data "aws_region" "current" {
  count = var.enabled ? 1 : 0
}

locals {
  account_id = try(data.aws_caller_identity.current[0].account_id, "")
  partition  = try(data.aws_partition.current[0].partition, "aws")
  region     = try(data.aws_region.current[0].name, "eu-west-1")
}

resource "aws_kms_key" "platform" {
  count                   = var.enabled ? 1 : 0
  description             = "Valeo platform baseline CMK"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
  lifecycle {
    prevent_destroy = true
  }
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountRoot"
        Effect    = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${local.region}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${local.partition}:logs:${local.region}:${local.account_id}:*"
          }
        }
      },
      {
        Sid    = "AllowConfigBackupSnsCloudTrail"
        Effect = "Allow"
        Principal = {
          Service = [
            "config.amazonaws.com",
            "backup.amazonaws.com",
            "sns.amazonaws.com",
            "cloudtrail.amazonaws.com",
          ]
        }
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "platform" {
  count         = var.enabled ? 1 : 0
  name          = var.alias
  target_key_id = aws_kms_key.platform[0].id
}

output "key_arn" {
  value = try(aws_kms_key.platform[0].arn, null)
}

output "key_id" {
  value = try(aws_kms_key.platform[0].key_id, null)
}
