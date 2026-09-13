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

resource "aws_sns_topic" "alarms" {
  count             = var.enabled ? 1 : 0
  name              = "valeotf-alarms"
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_policy" "alarms" {
  count = var.enabled ? 1 : 0
  arn   = aws_sns_topic.alarms[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudWatch"
      Effect    = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.alarms[0].arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "platform" {
  count             = var.enabled ? 1 : 0
  name              = "/valeotf/platform"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

output "alarm_topic_arn" {
  value = try(aws_sns_topic.alarms[0].arn, null)
}

output "log_group_name" {
  value = try(aws_cloudwatch_log_group.platform[0].name, null)
}
