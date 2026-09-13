# Account provisioning

How to request a **new** or **adopt-existing** account. Diagrams: [FLOW.md](FLOW.md). Poster check: [VALEO-ALIGNMENT.md](VALEO-ALIGNMENT.md).

Schema: `schemas/account-request.schema.yaml`.  
Do not use AWS-only field names (`AWSAccountName`). Use `account.name`, `cloud.provider`, `cloud.region`, `account.requested_ou`.

## New account

```text
User → YAML/JSON → Git → schema + policy → terraform plan → approval
  → terraform apply → Control Tower → member account
  → cross-account role → modules → AWS resources
```

1. Add a file under `requests/aws/<env>/`.
2. Set `account.contact_email` (required for vending).
3. Keep `migration.dry_run: true` until a reviewed plan exists.
4. Merge request → GitLab `request-validate` … `approval` → apply (off unless `VALEOTF_ENABLE_APPLY=true`).

Control Tower enrollment without a Terraform resource goes through the adapter (`enroll_if_unenrolled`). See [CONTROL-TOWER.md](CONTROL-TOWER.md).

Example: `requests/aws/dev/example-nonprod.yaml`.

## Adopt existing

Does **not** recreate the account.

```yaml
account:
  existing_account_id: "123456789012"
migration:
  mode: adopt-existing
  batch_id: batch-001
  dry_run: true
```

Then: inventory → import map → plan → `check-plan` (stop on destroy/replace) → approve → manage.  
See [MIGRATION.md](MIGRATION.md).

## Pipeline gates

VALIDATION → PLAN → APPROVAL → APPLY  

Production apply is GitLab **manual**. Details: [GITLAB-CICD.md](GITLAB-CICD.md).
