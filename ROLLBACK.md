# Rollback

## Terraform apply rollback

1. Do not `terraform destroy` a member account
2. Use S3 state versions to restore a previous state object if state is corrupted
3. Re-apply a known-good Git SHA after `valeotf check-plan`
4. If Control Tower enrollment was requested via the adapter/external API, roll that back with Control Tower/Organizations processes — not with Terraform destroy of the account

## Failed import

1. `terraform state rm` the bad address
2. Leave the AWS resource in place
3. Mark VALIDATION_FAILED
4. Re-inventory and re-map

## Failed batch

Keep the batch size small enough that rollback is an account list, not the organization. Production batches happen last.

## Legacy fallback

Until Phase 6, the previous Service Catalog / StackSet path remains the production fallback. Do not delete StackSets as a rollback step; that is decommission, and only after Terraform ownership is proven.
