"""Policy validation kept separate from Terraform modules."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from valeotf.io import load_yaml, repo_root


@dataclass
class PolicyResult:
    ok: bool
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


def load_policies(root: Path | None = None) -> dict[str, Any]:
    base = (root or repo_root()) / "policies"
    return {
        "account": load_yaml(base / "account" / "account.yaml"),
        "security": load_yaml(base / "security" / "security.yaml"),
        "network": load_yaml(base / "networking" / "network.yaml"),
        "governance": load_yaml(base / "governance" / "governance.yaml"),
    }


def validate_policies(request: dict[str, Any], root: Path | None = None) -> PolicyResult:
    policies = load_policies(root)
    errors: list[str] = []
    warnings: list[str] = []

    account = request.get("account") or {}
    cloud = request.get("cloud") or {}
    tags = request.get("tags") or {}
    network = request.get("network") or {}
    security = request.get("security") or {}
    baseline = request.get("baseline") or {}
    governance = request.get("governance") or {}
    environment = account.get("environment")

    account_pol = policies["account"]
    region = cloud.get("region")
    if region not in account_pol["approved_regions"]:
        errors.append(f"region '{region}' is not approved")
    extra_regions = cloud.get("additional_regions") or []
    for extra in extra_regions:
        if extra not in account_pol["approved_regions"]:
            errors.append(f"additional region '{extra}' is not approved")

    if environment not in account_pol["approved_environments"]:
        errors.append(f"environment '{environment}' is not approved")

    name = account.get("name") or ""
    pattern = account_pol["account_name"]["pattern"]
    if not re.match(pattern, name):
        errors.append(f"account name '{name}' does not match naming convention")
    if len(name) > account_pol["account_name"]["max_length"]:
        errors.append("account name exceeds max length")
    for prefix in account_pol["account_name"]["forbidden_prefixes"]:
        if name.startswith(prefix):
            errors.append(f"account name must not start with '{prefix}'")

    for tag in account_pol["required_tags"]:
        if not tags.get(tag):
            errors.append(f"required tag '{tag}' is missing")

    expected_ou = account_pol["ou_by_environment"].get(environment)
    requested_ou = account.get("requested_ou")
    if expected_ou and requested_ou != expected_ou:
        errors.append(
            f"requested_ou '{requested_ou}' is not allowed for environment '{environment}' "
            f"(expected '{expected_ou}')"
        )

    security_pol = policies["security"]
    if security_pol.get("encryption_required") and security.get("encryption") is not True:
        errors.append("encryption is required")
    if security_pol.get("monitoring_required") and security.get("monitoring") is not True:
        errors.append("monitoring is required")

    network_pol = policies["network"]
    profile = network.get("network_profile")
    if profile and profile not in network_pol["approved_network_profiles"]:
        errors.append(f"network_profile '{profile}' is not approved")
    if environment in network_pol["network_required_environments"]:
        if network.get("required") is not True:
            errors.append(f"network is required for environment '{environment}'")
    if environment == "prod" and profile in network_pol.get("prod_forbidden_profiles", []):
        errors.append("production accounts cannot use network_profile 'none'")

    gov_pol = policies["governance"]
    if gov_pol.get("control_tower_required") and governance.get("control_tower") is not True:
        errors.append("Control Tower governance is required")
    if gov_pol.get("config_required") and baseline.get("config") is False:
        errors.append("AWS Config baseline is required")
    if gov_pol.get("logging_required") and baseline.get("logging") is False:
        errors.append("logging baseline is required")
    if environment in gov_pol.get("backup_required_environments", []) and baseline.get("backup") is not True:
        errors.append(f"backup is required for environment '{environment}'")

    migration = request.get("migration") or {}
    mode = migration.get("mode") or "new-account"
    if mode == "new-account" and not account.get("existing_account_id") and not account.get("contact_email"):
        errors.append("contact_email is required for new-account vending (Service Catalog / Account Factory equivalent)")
    if environment == "prod" and migration.get("dry_run") is False:
        warnings.append("production apply is blocked until a human approval gate succeeds")

    if cloud.get("provider") != "aws":
        errors.append(
            f"provider '{cloud.get('provider')}' is reserved in the schema but not implemented; "
            "do not fake a non-AWS provisioner"
        )

    return PolicyResult(ok=not errors, errors=errors, warnings=warnings)
