# Changelog

All notable changes to the Valeo Terraform Control Tower platform are documented in this file.

Status values used in this project:

- **PROPOSED** — design only
- **IN DEVELOPMENT** — code exists, not proven in AWS
- **IMPORTED** — resources exist in Terraform state
- **VALIDATED** — terraform plan reviewed with no unexpected destroy/replace
- **MIGRATED** — Terraform is the exclusive owner
- **DECOMMISSIONED** — legacy orchestration removed after proven ownership

## [0.4.0] - 2026-09-13

### Changed

- Engineering quality targeted at ≥90% with the same factory workflow
- CI stages generated from `pipeline/arc.yaml` (`valeotf generate-ci`)
- IAM permission boundaries; S3 deny-insecure-transport; GitLab Secret Detection template
- Scheduled drift plan job (never applies)
- `valeotf scorecard` separates engineering scores from proven-in-AWS scores (100% proven is not claimed)

## [0.3.0] - 2026-09-13

### Changed

- Same factory workflow; production-grade CI: OIDC tokens, Checkov, arc drift check, saved tfplan artifacts, apply uses saved plan only
- Member apply role no longer uses AdministratorAccess
- GitLab OIDC module (off by default) in the organization stack
- Provider default tags; KMS/Backup prevent_destroy

## [0.2.0] - 2026-09-13

### Changed

- GitLab CI now follows the same ordered factory arc as production: request → account factory → SCP → baseline → resources → approval → apply
- Terraform modules upgraded from markers to production resource sets (Config recorder+delivery, KMS policy, Backup plan, VPC+flow logs, IAM plan/apply roles, EC2 instance profile, RDS parameter/subnet groups)
- Account vending stack added as the Account Factory equivalent
- Empty EC2 SSM documents removed (they were unsafe to apply)

## [0.1.0] - 2026-09-13

### Added

- Repository foundation, cloud-neutral account request schema, and sample request
- Policy engine (regions, OUs, tags, naming, encryption, backup, monitoring)
- Terraform module skeletons and stack layouts (organization, account-baseline, account-resources)
- Inventory data model and file/AWS collectors (AWS collector is opt-in, dry-run by default)
- CloudFormation parser, resource mapping, StackSet analyzer, import-map generator
- Destructive-change detector for Terraform plan JSON
- Migration report generator (JSON + Markdown)
- `valeotf` CLI
- GitLab CI with validate / security / plan / **manual production approval** / apply
- Documentation distinguishing current, target, and incomplete migration
- Unit tests for schema, policy, mapping, import maps, and destructive detection

### Not done (intentionally)

- Live AWS apply against 579 accounts
- Automatic conversion of 86 StackSets into 86 Terraform modules
- Decommission of Service Catalog, Step Functions, CodePipeline, or StackSets
- Invented Terraform resources for unsupported Control Tower APIs
