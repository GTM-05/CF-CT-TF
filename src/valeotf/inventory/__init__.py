"""Normalized inventory models. Inventory is not Terraform state."""

from __future__ import annotations

from typing import Any, TypedDict


class InventoryAccount(TypedDict, total=False):
    account_id: str
    account_name: str
    ou: str
    region: str
    environment: str
    tags: dict[str, str]
    control_tower_status: str
    enabled_regions: list[str]
    resources: dict[str, list[dict[str, Any]]]
    source: str


RESOURCE_KEYS = (
    "iam_roles",
    "iam_policies",
    "iam_instance_profiles",
    "vpcs",
    "subnets",
    "route_tables",
    "security_groups",
    "kms_keys",
    "ec2_instances",
    "rds_instances",
    "ssm_documents",
    "backup_vaults",
    "cloudwatch_log_groups",
    "config_rules",
    "sns_topics",
    "eventbridge_rules",
    "secrets",
    "s3_buckets",
    "lambda_functions",
)


def empty_resources() -> dict[str, list[dict[str, Any]]]:
    return {key: [] for key in RESOURCE_KEYS}


def normalize_account(raw: dict[str, Any]) -> InventoryAccount:
    resources = empty_resources()
    incoming = raw.get("resources") or {}
    for key in RESOURCE_KEYS:
        value = incoming.get(key) or []
        resources[key] = list(value)
    return InventoryAccount(
        account_id=str(raw.get("account_id") or ""),
        account_name=str(raw.get("account_name") or ""),
        ou=str(raw.get("ou") or ""),
        region=str(raw.get("region") or ""),
        environment=str(raw.get("environment") or ""),
        tags=dict(raw.get("tags") or {}),
        control_tower_status=str(raw.get("control_tower_status") or "unknown"),
        enabled_regions=list(raw.get("enabled_regions") or []),
        resources=resources,
        source=str(raw.get("source") or "file"),
    )
