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

variable "network_profile" {
  type = string
  validation {
    condition     = contains(["none", "standard", "isolated", "shared"], var.network_profile)
    error_message = "network_profile must be none, standard, isolated, or shared."
  }
}

variable "cidr_block" {
  type    = string
  default = "10.80.0.0/16"
}

variable "kms_key_arn" {
  type     = string
  default  = null
  nullable = true
}

locals {
  create = var.enabled && var.network_profile != "none"
}

data "aws_availability_zones" "available" {
  count = local.create ? 1 : 0
  state = "available"
}

resource "aws_vpc" "baseline" {
  count                = local.create ? 1 : 0
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "valeotf-baseline" })
}

resource "aws_default_security_group" "baseline" {
  count  = local.create ? 1 : 0
  vpc_id = aws_vpc.baseline[0].id
  tags   = merge(var.tags, { Name = "valeotf-default-deny" })
}

resource "aws_subnet" "private" {
  count             = local.create ? 2 : 0
  vpc_id            = aws_vpc.baseline[0].id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index)
  availability_zone = data.aws_availability_zones.available[0].names[count.index]
  tags              = merge(var.tags, { Name = "valeotf-private-${count.index}" })
}

resource "aws_route_table" "private" {
  count  = local.create ? 1 : 0
  vpc_id = aws_vpc.baseline[0].id
  tags   = merge(var.tags, { Name = "valeotf-private" })
}

resource "aws_route_table_association" "private" {
  count          = local.create ? 2 : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_flow_log" "vpc" {
  count                    = local.create ? 1 : 0
  vpc_id                   = aws_vpc.baseline[0].id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow[0].arn
  iam_role_arn             = aws_iam_role.flow[0].arn
  max_aggregation_interval = 600
  tags                     = var.tags
}

resource "aws_cloudwatch_log_group" "flow" {
  count             = local.create ? 1 : 0
  name              = "/valeotf/vpc-flow"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "flow_trust" {
  count = local.create ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  count              = local.create ? 1 : 0
  name               = "valeotf-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_trust[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "flow" {
  count = local.create ? 1 : 0
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.flow[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  count  = local.create ? 1 : 0
  name   = "valeotf-vpc-flow-logs"
  role   = aws_iam_role.flow[0].id
  policy = data.aws_iam_policy_document.flow[0].json
}

output "vpc_id" {
  value = try(aws_vpc.baseline[0].id, null)
}

output "private_subnet_ids" {
  value = try(aws_subnet.private[*].id, [])
}
