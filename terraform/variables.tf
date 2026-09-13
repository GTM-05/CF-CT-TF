variable "region" {
  type        = string
  description = "Primary AWS region for the default provider."
}

variable "terraform_role_arn" {
  type        = string
  description = "Role assumed in the member account. Never a long-lived access key."
  default     = ""
}

variable "external_id" {
  type        = string
  description = "Optional STS external ID."
  default     = ""
  sensitive   = true
}
