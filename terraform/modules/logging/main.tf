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

variable "create_account_cloudtrail" {
  type        = bool
  default     = false
  description = "Leave false when an organization trail already exists. Enable only when this account must own a local trail."
}

data "aws_caller_identity" "current" {
  count = var.enabled ? 1 : 0
}

data "aws_region" "current" {
  count = var.enabled ? 1 : 0
}

resource "aws_cloudwatch_log_group" "logging" {
  count             = var.enabled ? 1 : 0
  name              = "/valeotf/logging"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_s3_bucket" "trail" {
  count  = var.enabled && var.create_account_cloudtrail ? 1 : 0
  bucket = "valeotf-trail-${data.aws_caller_identity.current[0].account_id}-${data.aws_region.current[0].name}"
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "trail" {
  count                   = var.enabled && var.create_account_cloudtrail ? 1 : 0
  bucket                  = aws_s3_bucket.trail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  count  = var.enabled && var.create_account_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

data "aws_iam_policy_document" "trail_bucket" {
  count = var.enabled && var.create_account_cloudtrail ? 1 : 0
  statement {
    sid     = "AWSCloudTrailAclCheck"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [aws_s3_bucket.trail[0].arn]
  }
  statement {
    sid     = "AWSCloudTrailWrite"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.trail[0].arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.trail[0].arn,
      "${aws_s3_bucket.trail[0].arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  count  = var.enabled && var.create_account_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  policy = data.aws_iam_policy_document.trail_bucket[0].json
}

resource "aws_cloudtrail" "account" {
  count                         = var.enabled && var.create_account_cloudtrail ? 1 : 0
  name                          = "valeotf-account"
  s3_bucket_name                = aws_s3_bucket.trail[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.logging[0].arn}:*"
  depends_on                    = [aws_s3_bucket_policy.trail]
  tags                          = var.tags
}

output "log_group_name" {
  value = try(aws_cloudwatch_log_group.logging[0].name, null)
}

output "cloudtrail_arn" {
  value = try(aws_cloudtrail.account[0].arn, null)
}
