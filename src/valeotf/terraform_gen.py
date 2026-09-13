"""Render Terraform variable files from a cloud-neutral account request."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml


def request_to_tfvars(request: dict[str, Any]) -> dict[str, Any]:
    account = request["account"]
    cloud = request["cloud"]
    baseline = request.get("baseline") or {}
    network = request.get("network") or {}
    security = request.get("security") or {}
    governance = request.get("governance") or {}
    tags = request.get("tags") or {}
    migration = request.get("migration") or {}

    account_id = account.get("existing_account_id") or ""
    return {
        "account_name": account["name"],
        "account_id": account_id,
        "environment": account["environment"],
        "business_unit": account.get("business_unit", ""),
        "country": account.get("country", ""),
        "requested_ou": account["requested_ou"],
        "owner": account["owner"],
        "account_email": account.get("contact_email") or "",
        "region": cloud["region"],
        "additional_regions": cloud.get("additional_regions") or [],
        "enable_control_tower_governance": bool(governance.get("control_tower")),
        "required_controls": governance.get("required_controls") or [],
        "enroll_if_unenrolled": bool(governance.get("enroll_if_unenrolled")),
        "enable_network": bool(network.get("required")),
        "network_profile": network.get("network_profile") or "none",
        "enable_encryption": bool(security.get("encryption")),
        "enable_monitoring": bool(security.get("monitoring")),
        "enable_iam": bool(baseline.get("iam", True)),
        "enable_ec2_baseline": bool(baseline.get("ec2")),
        "enable_rds_baseline": bool(baseline.get("rds")),
        "enable_backup": bool(baseline.get("backup")),
        "enable_ssm": bool(baseline.get("ssm")),
        "enable_config": bool(baseline.get("config")),
        "enable_logging": bool(baseline.get("logging")),
        "enable_kms": bool(baseline.get("kms", True)),
        "tags": tags,
        "migration_mode": migration.get("mode") or "new-account",
        "dry_run": migration.get("dry_run", True),
        "batch_id": migration.get("batch_id") or "",
    }


def write_tfvars(path: Path, values: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rendered = yaml.safe_dump(values, sort_keys=False)
    path.write_text(rendered, encoding="utf-8")


def write_backend_hcl(path: Path, *, bucket: str, key: str, region: str, dynamodb_table: str, kms_key_id: str | None = None) -> None:
    """Write a backend config file. Never hard-code a backend inside modules."""
    lines = [
        f'bucket         = "{bucket}"',
        f'key            = "{key}"',
        f'region         = "{region}"',
        f'dynamodb_table = "{dynamodb_table}"',
        "encrypt        = true",
    ]
    if kms_key_id:
        lines.append(f'kms_key_id     = "{kms_key_id}"')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def state_key(account_id: str, environment: str, region: str, stack: str) -> str:
    identity = account_id or "unassigned"
    return f"aws/account-{identity}/{environment}/{region}/{stack}.tfstate"
