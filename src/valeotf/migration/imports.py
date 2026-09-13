"""Generate terraform import candidates from inventory + mapping. Never auto-apply."""

from __future__ import annotations

from typing import Any

from valeotf.inventory import InventoryAccount

OWNERSHIP_STATES = (
    "DISCOVERED",
    "ANALYZED",
    "READY_FOR_IMPORT",
    "IMPORTED",
    "TERRAFORM_MANAGED",
    "VALIDATION_FAILED",
    "MANUAL_REVIEW",
    "RETAIN",
    "REMOVE",
)

INVENTORY_TO_CFN = {
    "iam_roles": "AWS::IAM::Role",
    "kms_keys": "AWS::KMS::Key",
    "vpcs": "AWS::EC2::VPC",
    "subnets": "AWS::EC2::Subnet",
    "route_tables": "AWS::EC2::RouteTable",
    "security_groups": "AWS::EC2::SecurityGroup",
    "ec2_instances": None,
    "rds_instances": None,
    "ssm_documents": "AWS::SSM::Document",
    "backup_vaults": "AWS::Backup::BackupVault",
    "cloudwatch_log_groups": "AWS::Logs::LogGroup",
    "config_rules": "AWS::Config::ConfigRule",
    "sns_topics": "AWS::SNS::Topic",
    "eventbridge_rules": "AWS::Events::Rule",
    "s3_buckets": "AWS::S3::Bucket",
    "lambda_functions": "AWS::Lambda::Function",
    "secrets": "AWS::SecretsManager::Secret",
    "iam_instance_profiles": "AWS::IAM::InstanceProfile",
}


def generate_import_map(
    accounts: list[InventoryAccount],
    mapping: dict[str, Any],
    *,
    ownership: dict[str, str] | None = None,
) -> list[dict[str, Any]]:
    """
    Produce import candidates. Resources already CloudFormation-owned stay pending
    until ownership is flipped. Inventory is never treated as Control Tower import.
    """
    ownership = ownership or {}
    candidates: list[dict[str, Any]] = []
    for account in accounts:
        for resource_key, items in (account.get("resources") or {}).items():
            cfn_type = INVENTORY_TO_CFN.get(resource_key)
            mapped = mapping.get(cfn_type or "", {})
            terraform = mapped.get("terraform")
            for item in items:
                resource_id = item.get("id") or item.get("arn") or item.get("name")
                if not resource_id:
                    continue
                current_owner = item.get("owner") or ownership.get(str(resource_id), "DISCOVERED")
                action = mapped.get("action_default") if mapped else "MANUAL_REVIEW_REQUIRED"
                if current_owner in {"CloudFormation-owned", "SHARED", "Shared / Manual"}:
                    status = "MANUAL_REVIEW"
                    notes = "Do not import while CloudFormation still owns this resource."
                elif not terraform or action in {"MANUAL_REVIEW", "MANUAL REVIEW", "MANUAL_REVIEW_REQUIRED"}:
                    status = "MANUAL_REVIEW"
                    notes = "No safe Terraform mapping or mapping requires manual review."
                    action = action or "MANUAL_REVIEW_REQUIRED"
                else:
                    status = "READY_FOR_IMPORT"
                    notes = "Candidate only. Run terraform plan after import; stop on destroy/replace."
                candidates.append(
                    {
                        "account_id": account.get("account_id"),
                        "region": account.get("region"),
                        "inventory_key": resource_key,
                        "cfn_type": cfn_type,
                        "terraform_type": terraform,
                        "resource_id": resource_id,
                        "name": item.get("name"),
                        "legacy_stackset": item.get("stackset"),
                        "owner": current_owner,
                        "migration_status": status,
                        "action": action,
                        "import_command": (
                            f"terraform import {terraform}.imported_{_safe_addr(resource_id)} {resource_id}"
                            if terraform and status == "READY_FOR_IMPORT"
                            else None
                        ),
                        "notes": notes,
                    }
                )
    return candidates


def _safe_addr(value: str) -> str:
    allowed = []
    for char in value:
        allowed.append(char if char.isalnum() else "_")
    return "".join(allowed)[:64]
