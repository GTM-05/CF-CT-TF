variable "account_name" { type = string }
variable "account_id" {
  type    = string
  default = ""
}
variable "environment" { type = string }
variable "business_unit" {
  type    = string
  default = ""
}
variable "country" {
  type    = string
  default = ""
}
variable "requested_ou" { type = string }
variable "owner" { type = string }
variable "region" { type = string }
variable "additional_regions" {
  type    = list(string)
  default = []
}
variable "enable_control_tower_governance" {
  type    = bool
  default = true
}
variable "required_controls" {
  type    = list(string)
  default = []
}
variable "enroll_if_unenrolled" {
  type    = bool
  default = false
}
variable "enable_network" {
  type    = bool
  default = true
}
variable "network_profile" {
  type    = string
  default = "standard"
}
variable "enable_encryption" {
  type    = bool
  default = true
}
variable "enable_monitoring" {
  type    = bool
  default = true
}
variable "enable_iam" {
  type    = bool
  default = true
}
variable "enable_ec2_baseline" {
  type    = bool
  default = false
}
variable "enable_rds_baseline" {
  type    = bool
  default = false
}
variable "enable_backup" {
  type    = bool
  default = true
}
variable "enable_ssm" {
  type    = bool
  default = true
}
variable "enable_config" {
  type    = bool
  default = true
}
variable "enable_logging" {
  type    = bool
  default = true
}
variable "enable_kms" {
  type    = bool
  default = true
}
variable "tags" { type = map(string) }
variable "migration_mode" {
  type    = string
  default = "new-account"
}
variable "dry_run" {
  type    = bool
  default = true
}
variable "batch_id" {
  type    = string
  default = ""
}
variable "terraform_role_arn" {
  type    = string
  default = ""
}
variable "external_id" {
  type      = string
  default   = ""
  sensitive = true
}
variable "trusted_principal_arns" {
  type    = list(string)
  default = []
}
variable "account_email" {
  type    = string
  default = ""
}