data "aws_iam_policy_document" "apply" {
  count = var.enabled ? 1 : 0

  statement {
    sid    = "PlatformBaselineServices"
    effect = "Allow"
    actions = [
      "backup:*",
      "cloudtrail:*",
      "cloudwatch:*",
      "config:*",
      "ec2:*",
      "events:*",
      "iam:*",
      "kms:*",
      "logs:*",
      "rds:*",
      "s3:*",
      "sns:*",
      "ssm:*",
      "sts:AssumeRole",
      "sts:GetCallerIdentity",
      "tag:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyAccountBreakGlass"
    effect = "Deny"
    actions = [
      "iam:CreateAccessKey",
      "iam:CreateUser",
      "iam:DeleteAccountPasswordPolicy",
      "organizations:LeaveOrganization",
      "account:CloseAccount",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "apply" {
  count       = var.enabled ? 1 : 0
  name        = "valeotf-terraform-apply"
  description = "Service-scoped apply policy for platform baselines. Permission boundary still applies."
  policy      = data.aws_iam_policy_document.apply[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "apply" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.apply[0].name
  policy_arn = aws_iam_policy.apply[0].arn
}