# Terraform state

State answers **what Terraform manages**. Inventory answers **what exists**. Keep them separate.

## Blast radius

Preferred key layout:

```text
aws/account-<id>/<environment>/<region>/<stack>.tfstate
```

Examples: `baseline`, `organization`, `account-resources`.

Do not store 579 accounts in one state file.

## Controls

| Requirement | Mechanism |
| --- | --- |
| Encryption | S3 SSE + optional KMS |
| Locking | DynamoDB lock table |
| Versioning | S3 versioning |
| Access | IAM on bucket/table; plan vs apply roles |
| Recovery | Version restore; documented in ROLLBACK.md |
| Audit | Bucket access logs + GitLab job logs (no secrets) |

## Backend is configurable

Modules do not hard-code backends. Stacks use `backend "s3" {}` filled by `terraform init -backend-config=backend.hcl`.

Copy `terraform/backend.hcl.example`. Never commit real credentials. Bucket names may be committed if they are not secret; this repo uses placeholders.
