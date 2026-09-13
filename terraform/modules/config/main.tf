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

data "aws_caller_identity" "current" {
  count = var.enabled ? 1 : 0
}

data "aws_region" "current" {
  count = var.enabled ? 1 : 0
}

data "aws_partition" "current" {
  count = var.enabled ? 1 : 0
}

locals {
  account_id = try(data.aws_caller_identity.current[0].account_id, "")
  region     = try(data.aws_region.current[0].name, "eu-west-1")
  bucket     = "valeotf-config-${local.account_id}-${local.region}"
}

data "aws_iam_policy_document" "config_trust" {
  count = var.enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  count              = var.enabled ? 1 : 0
  name               = "valeotf-config"
  assume_role_policy = data.aws_iam_policy_document.config_trust[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_s3_bucket" "config" {
  count  = var.enabled ? 1 : 0
  bucket = local.bucket
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "config" {
  count                   = var.enabled ? 1 : 0
  bucket                  = aws_s3_bucket.config[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count  = var.enabled ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "config" {
  count  = var.enabled ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "config_bucket" {
  count = var.enabled ? 1 : 0
  statement {
    sid     = "AWSConfigBucketPermissionsCheck"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = [aws_s3_bucket.config[0].arn]
  }
  statement {
    sid     = "AWSConfigBucketExistenceCheck"
    actions = ["s3:ListBucket"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = [aws_s3_bucket.config[0].arn]
  }
  statement {
    sid     = "AWSConfigBucketDelivery"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.config[0].arn}/*"]
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
      aws_s3_bucket.config[0].arn,
      "${aws_s3_bucket.config[0].arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  count  = var.enabled ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  policy = data.aws_iam_policy_document.config_bucket[0].json
}

resource "aws_config_configuration_recorder" "this" {
  count    = var.enabled ? 1 : 0
  name     = "valeotf"
  role_arn = aws_iam_role.config[0].arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "this" {
  count          = var.enabled ? 1 : 0
  name           = "valeotf"
  s3_bucket_name = aws_s3_bucket.config[0].bucket
  depends_on     = [aws_config_configuration_recorder.this, aws_s3_bucket_policy.config]
}

resource "aws_config_configuration_recorder_status" "this" {
  count      = var.enabled ? 1 : 0
  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

resource "aws_config_config_rule" "encrypted_volumes" {
  count = var.enabled ? 1 : 0
  name  = "valeotf-encrypted-volumes"
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
  depends_on = [aws_config_configuration_recorder_status.this]
}

output "recorder_name" {
  value = try(aws_config_configuration_recorder.this[0].name, null)
}

output "bucket_id" {
  value = try(aws_s3_bucket.config[0].id, null)
}
