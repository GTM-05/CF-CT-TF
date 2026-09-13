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
variable "name" { type = string }
variable "content" { type = string }
variable "target_ids" {
  type        = list(string)
  default     = []
  description = "OU or account ids for attachment. Separate from policy document."
}

resource "aws_organizations_policy" "scp" {
  count       = var.enabled ? 1 : 0
  name        = var.name
  type        = "SERVICE_CONTROL_POLICY"
  content     = var.content
  description = "Managed by valeotf. Production changes require approval."
}

resource "aws_organizations_policy_attachment" "targets" {
  for_each  = var.enabled ? toset(var.target_ids) : toset([])
  policy_id = aws_organizations_policy.scp[0].id
  target_id = each.value
}

output "policy_id" {
  value = try(aws_organizations_policy.scp[0].id, null)
}
