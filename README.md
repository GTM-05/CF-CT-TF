# Valeo Terraform Control Tower Platform

Terraform is the provisioning engine. AWS Control Tower remains the governance boundary. Git + GitLab CI is the orchestrator.

This repository is **IN DEVELOPMENT**. It does not claim that 579 accounts or ~86 StackSets are migrated.

## Principle

First discover → then map → then import → then plan → then approve → then manage.

Never start by replacing existing accounts or StackSets.

## What this is not

- Not 86 CloudFormation StackSets converted into 86 Terraform modules
- Not a recreation of Service Catalog + EventBridge + Step Functions + CodePipeline
- Not Terraform replacing Control Tower
- Not live AWS apply in v0.1.0 (dry-run by default)

## Quick start

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

valeotf validate-request requests/aws/dev/example-nonprod.yaml
valeotf arc --request requests/aws/dev/example-nonprod.yaml
valeotf inventory accounts
valeotf analyze-stacksets
valeotf analyze-template ec2-baseline-stack.template.yaml
valeotf generate-import-map
valeotf migration-report
```

Terraform validation (no backend, no apply):

```bash
terraform -chdir=terraform/stacks/account-baseline init -backend=false
terraform -chdir=terraform/stacks/account-baseline validate -var-file=terraform.tfvars.example
```

## CLI

| Command | Purpose |
| --- | --- |
| `valeotf inventory` | Normalized inventory (fixtures unless `--live`) |
| `valeotf analyze-stacksets` | Migration matrix, with CONSOLIDATE/REMOVE |
| `valeotf analyze-template <file>` | CloudFormation → Terraform mapping |
| `valeotf generate-import-map` | Import candidates only |
| `valeotf generate-terraform <request>` | tfvars from a cloud-neutral request |
| `valeotf validate-request <file>` | Schema + policy |
| `valeotf plan` | Terraform plan + destroy/replace stop |
| `valeotf apply --approve` | Blocked if the plan is destructive |
| `valeotf migration-status` | JSON report |
| `valeotf check-plan <plan.json>` | CI gate for destructive changes |

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [MIGRATION.md](MIGRATION.md)
- [ACCOUNT-PROVISIONING.md](ACCOUNT-PROVISIONING.md)
- [TERRAFORM-STATE.md](TERRAFORM-STATE.md)
- [INVENTORY.md](INVENTORY.md)
- [CLOUDFORMATION-TO-TERRAFORM.md](CLOUDFORMATION-TO-TERRAFORM.md)
- [SECURITY.md](SECURITY.md)
- [OPERATIONS.md](OPERATIONS.md)
- [ROLLBACK.md](ROLLBACK.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)

## Safety

- Production apply requires GitLab **manual** approval
- `dry_run: true` in requests disables member-account resource creation
- Plans that destroy or replace **must stop**
- Secrets never belong in Git, tfvars, outputs, or CI logs
- Inventory is not Control Tower enrollment and is not Terraform state
