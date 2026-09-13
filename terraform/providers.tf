provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "member"
  region = var.region

  dynamic "assume_role" {
    for_each = var.terraform_role_arn == "" ? [] : [var.terraform_role_arn]
    content {
      role_arn    = assume_role.value
      external_id = var.external_id == "" ? null : var.external_id
    }
  }
}
