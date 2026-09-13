# CloudFormation to Terraform

Do not generate one Terraform module per StackSet.

## Matrix

```bash
valeotf analyze-stacksets --write
valeotf analyze-template ec2-baseline-stack.template.yaml
```

Actions: MIGRATE, CONSOLIDATE, RETAIN, REMOVE, MANUAL REVIEW.

Orchestration types (Step Functions, CodePipeline, CodeBuild, StackSets, Service Catalog provisioned products) default to **REMOVE** after Terraform ownership, not to Terraform recreations of the orchestrator.

## Type mapping

The table lives in `migration/mappings/cfn-to-terraform.json`. Examples:

| CloudFormation | Terraform |
| --- | --- |
| AWS::IAM::Role | aws_iam_role |
| AWS::KMS::Key | aws_kms_key |
| AWS::EC2::SecurityGroup | aws_security_group |
| AWS::S3::Bucket | aws_s3_bucket |
| AWS::SNS::Topic | aws_sns_topic |
| AWS::SSM::Document | aws_ssm_document |
| AWS::Backup::BackupVault | aws_backup_vault |
| AWS::Config::ConfigRule | aws_config_config_rule |

Unmapped types are `MANUAL_REVIEW_REQUIRED`.

## Import

`valeotf generate-import-map` emits candidates. Resources still `CloudFormation-owned` stay MANUAL_REVIEW. After import, `terraform plan` must be clean of destroy/replace before claiming TERRAFORM_MANAGED.
