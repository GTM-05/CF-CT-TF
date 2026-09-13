output "member_provider_configured" {
  value       = var.terraform_role_arn != ""
  description = "Whether the member alias will assume a role."
}
