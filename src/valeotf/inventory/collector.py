"""Inventory collectors. Default path is fixtures/files. Live AWS is opt-in."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from valeotf.inventory import InventoryAccount, normalize_account
from valeotf.io import repo_root


def collect_from_directory(path: Path | None = None) -> list[InventoryAccount]:
    directory = path or (repo_root() / "inventory" / "generated")
    if path is None:
        generated = repo_root() / "inventory" / "generated"
        fixtures = repo_root() / "inventory" / "fixtures"
        if generated.exists() and any(generated.glob("*.json")):
            directory = generated
        else:
            directory = fixtures
    accounts: list[InventoryAccount] = []
    for file in sorted(directory.glob("*.json")):
        payload = json.loads(file.read_text(encoding="utf-8"))
        if isinstance(payload, list):
            accounts.extend(normalize_account(item) for item in payload)
        else:
            accounts.append(normalize_account(payload))
    return accounts


def collect_accounts_metadata(accounts: list[InventoryAccount]) -> list[dict[str, Any]]:
    return [
        {
            "account_id": item["account_id"],
            "account_name": item["account_name"],
            "ou": item["ou"],
            "environment": item["environment"],
            "control_tower_status": item["control_tower_status"],
            "region": item["region"],
        }
        for item in accounts
    ]


def collect_aws_organizations(*, dry_run: bool = True) -> list[InventoryAccount]:
    """Live Organizations inventory. Never mutates AWS. Disabled unless dry_run is False and boto3 is used."""
    if dry_run:
        return collect_from_directory()
    try:
        import boto3  # type: ignore
    except ImportError as exc:
        raise RuntimeError("boto3 is required for live inventory; install valeotf[aws]") from exc

    org = boto3.client("organizations")
    paginator = org.get_paginator("list_accounts")
    results: list[InventoryAccount] = []
    for page in paginator.paginate():
        for account in page.get("Accounts", []):
            results.append(
                normalize_account(
                    {
                        "account_id": account["Id"],
                        "account_name": account["Name"],
                        "control_tower_status": "unknown",
                        "source": "aws-organizations",
                        "tags": {},
                        "resources": {},
                    }
                )
            )
    return results
