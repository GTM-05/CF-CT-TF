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

variable "subnet_ids" {
  type    = list(string)
  default = []
}

resource "aws_iam_role" "monitoring" {
  count = var.enabled ? 1 : 0
  name  = "valeotf-rds-monitoring"
  tags  = var.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_subnet_group" "this" {
  count      = var.enabled && length(var.subnet_ids) >= 2 ? 1 : 0
  name       = "valeotf-rds"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_db_parameter_group" "postgres" {
  count  = var.enabled ? 1 : 0
  name   = "valeotf-postgres16"
  family = "postgres16"
  tags   = var.tags
}

resource "aws_db_parameter_group" "mysql" {
  count  = var.enabled ? 1 : 0
  name   = "valeotf-mysql8"
  family = "mysql8.0"
  tags   = var.tags
}

output "monitoring_role_arn" {
  value = try(aws_iam_role.monitoring[0].arn, null)
}

output "subnet_group_name" {
  value = try(aws_db_subnet_group.this[0].name, null)
}

output "kms_key_arn" {
  value = var.kms_key_arn
}
