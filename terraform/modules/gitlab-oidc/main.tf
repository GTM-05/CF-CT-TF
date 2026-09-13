terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "enabled" {
  type    = bool
  default = false
}

variable "gitlab_url" {
  type    = string
  default = "https://gitlab.com"
}

variable "oidc_audience" {
  type    = string
  default = "https://gitlab.com"
}

variable "plan_bound_claims" {
  type        = list(string)
  default     = []
  description = "Allowed token sub values for plan (e.g. project_path:group/project:ref_type:branch:ref:main)."
}

variable "apply_bound_claims" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "tls_certificate" "gitlab" {
  count = var.enabled ? 1 : 0
  url   = var.gitlab_url
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  count           = var.enabled ? 1 : 0
  url             = var.gitlab_url
  client_id_list  = [var.oidc_audience]
  thumbprint_list = [data.tls_certificate.gitlab[0].certificates[0].sha1_fingerprint]
  tags            = var.tags
}

data "aws_iam_policy_document" "plan_trust" {
  count = var.enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.gitlab[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.gitlab_url, "https://", "")}:aud"
      values   = [var.oidc_audience]
    }
    condition {
      test     = "StringLike"
      variable = "${replace(var.gitlab_url, "https://", "")}:sub"
      values   = length(var.plan_bound_claims) > 0 ? var.plan_bound_claims : ["project_path:*"]
    }
  }
}

resource "aws_iam_role" "gitlab_plan" {
  count              = var.enabled ? 1 : 0
  name               = "valeotf-gitlab-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust[0].json
  tags               = merge(var.tags, { valeotf = "oidc-plan" })
}

resource "aws_iam_role_policy_attachment" "gitlab_plan" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.gitlab_plan[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

output "oidc_provider_arn" {
  value = try(aws_iam_openid_connect_provider.gitlab[0].arn, null)
}

output "gitlab_plan_role_arn" {
  value = try(aws_iam_role.gitlab_plan[0].arn, null)
}
