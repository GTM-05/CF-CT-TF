data "aws_iam_policy_document" "boundary" {
  count = var.enabled ? 1 : 0

  statement {
    sid       = "AllowAllExceptBreakGlass"
    effect    = "Allow"
    resources = ["*"]
    not_actions = [
      "account:*",
      "billing:*",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:CreateUser",
      "iam:DeleteAccountPasswordPolicy",
      "organizations:LeaveOrganization",
      "organizations:DeregisterDelegatedAdministrator",
    ]
  }
}

resource "aws_iam_policy" "boundary" {
  count       = var.enabled ? 1 : 0
  name        = "valeotf-terraform-boundary"
  description = "Permission boundary for GitLab plan/apply roles."
  policy      = data.aws_iam_policy_document.boundary[0].json
  tags        = var.tags
}
