# Migration

Status: **PROPOSED / IN DEVELOPMENT**. Nothing in this repository is MIGRATED until Terraform state ownership is proven for that resource.

## Sequence

```text
EXISTING ENVIRONMENT
        |
+-------+--------+
|                |
v                v
579 ACCOUNTS   ~86 STACKSETS
|                |
v                v
INVENTORY     CFN ANALYSIS
|                |
+-------+--------+
        v
  MIGRATION MAP
        v
 TERRAFORM MODULES
        v
 IMPORT EXISTING
        v
 TERRAFORM PLAN
        v
    VALIDATE
        v
     APPROVE
        v
 TERRAFORM MANAGED
        v
DECOMMISSION LEGACY
```

Do not convert 86 StackSets into 86 modules. Analyze, then MIGRATE, CONSOLIDATE, RETAIN, REMOVE, or MANUAL REVIEW.

## Phases

### Phase 1 — Discovery (current focus)

- Inventory accounts, resources, Control Tower status
- Inventory StackSets and templates
- Record dependencies (IAM, KMS, SSM, Secrets ARNs, EventBridge, Lambda, SCPs)

### Phase 2 — Analysis

- Classify StackSets
- Map CloudFormation types
- Flag obsolete and orchestration-only resources
- Identify consolidation (example: EC2 users + EC2 baseline → one module)

### Phase 3 — Terraform platform

- Repo, modules, schema, policy, CI, state, cross-account role

### Phase 4 — Existing account adoption (batched)

Suggested batches: 5 non-prod → 25 → 50 → 100 → … → production last.

Each batch: inventory → import → plan → approval → apply → validate → rollback procedure.

### Phase 5 — New account provisioning

YAML → Git → validate → plan → approve → apply → Control Tower → member role → modules.

### Phase 6 — Decommission (only after proven ownership)

Service Catalog custom workflow, Account Factory wrapper, EventBridge, Step Functions, CodePipeline, CodeBuild, StackSet orchestration, obsolete templates.

## Safe migration rule

Before every migration batch:

1. `terraform plan` (JSON)
2. `valeotf check-plan` must pass
3. If the plan contains **destroy** or **replace**, **STOP**
4. Also stop for unexpected IAM, security group, KMS, or network updates

Never apply because a resource exists in AWS but is missing from state. Add it to inventory, decide ownership, then import or exclude.

## Ownership

Possible states: DISCOVERED, ANALYZED, READY_FOR_IMPORT, IMPORTED, TERRAFORM_MANAGED, VALIDATION_FAILED, MANUAL_REVIEW, RETAIN, REMOVE.

A resource must not be managed by CloudFormation and Terraform at the same time.

## EC2 baseline

Do not replace the live stack blindly. Inventory SSM documents, instance profiles, KMS, Secrets Manager ARNs (not values), EventBridge, Lambda, AD identifiers, SCPs. The `ec2-baseline` module is split into iam / ssm / secrets-ARN / events placeholders. Lambda termination and AD join remain MANUAL_REVIEW until inventoried.

## Control Tower vs import

- Inventory answers what exists
- Terraform import answers what will be in state
- Control Tower enrollment answers governance

Never treat inventory JSON as something to “load into Control Tower”.

## Reporting

```bash
valeotf migration-report --write
```

The report claim status stays **IN DEVELOPMENT** until batches are VALIDATED.

## Dry-run

Account requests default to `migration.dry_run: true`, which keeps member-account modules disabled. Apply remains a GitLab manual job for production.
