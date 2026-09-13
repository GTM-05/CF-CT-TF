# Operations

## Day-to-day

1. Merge request with request YAML and/or Terraform/module changes
2. `validate` + `security` + `terraform plan` in GitLab
3. Human review of plan
4. Manual apply for production
5. Record ownership in the import map / migration report

## Drift

A scheduled GitLab pipeline runs `terraform plan` only. Drift is reported. Production is never auto-applied.

Observability fields to retain in job logs: account id, environment, git SHA, Terraform version, module version, status, failed address, drift flag. No secrets.

## Batches

Use `migration.batch_id` on adopt-existing requests. Do not target all 579 accounts in one pipeline.

## Coexistence

Old and new systems may run in parallel. They must not write the same resource. Flip CloudFormation to retain/remove only after TERRAFORM_MANAGED.
