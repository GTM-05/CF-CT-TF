"""Migration status reports. Never claim MIGRATED without import + validated plan."""

from __future__ import annotations

from typing import Any

from valeotf.inventory import InventoryAccount


def build_report(
    *,
    accounts: list[InventoryAccount],
    stackset_rows: list[dict[str, Any]],
    import_candidates: list[dict[str, Any]],
    expected_accounts: int = 579,
    expected_stacksets: int = 86,
) -> dict[str, Any]:
    migrated_accounts = {
        item.get("account_id")
        for item in import_candidates
        if item.get("migration_status") == "TERRAFORM_MANAGED"
    }
    manual = [item for item in import_candidates if item.get("migration_status") == "MANUAL_REVIEW"]
    terraform_managed = [
        item for item in import_candidates if item.get("migration_status") in {"IMPORTED", "TERRAFORM_MANAGED"}
    ]
    remaining_stacksets = [
        row for row in stackset_rows if row.get("status") not in {"MIGRATED", "DECOMMISSIONED", "REMOVE"}
    ]
    return {
        "accounts_expected": expected_accounts,
        "accounts_inventoried": len(accounts),
        "stacksets_expected": expected_stacksets,
        "stacksets_analyzed": len(stackset_rows),
        "migrated_accounts": len(migrated_accounts),
        "pending_accounts": max(expected_accounts - len(migrated_accounts), 0),
        "terraform_managed_resources": len(terraform_managed),
        "manual_review": len(manual),
        "legacy_stacksets_remaining": len(remaining_stacksets),
        "migration_claim": "IN DEVELOPMENT",
        "notes": [
            "Inventory answers what exists. Terraform state answers what Terraform manages.",
            "Control Tower enrollment is a separate process from Terraform import.",
            "Do not claim CloudFormation has been migrated until state adoption is proven.",
        ],
    }


def report_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Migration report",
        "",
        f"**Claim status:** {report['migration_claim']}",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Accounts expected | {report['accounts_expected']} |",
        f"| Accounts inventoried | {report['accounts_inventoried']} |",
        f"| StackSets expected | {report['stacksets_expected']} |",
        f"| StackSets analyzed | {report['stacksets_analyzed']} |",
        f"| Migrated accounts | {report['migrated_accounts']} |",
        f"| Pending accounts | {report['pending_accounts']} |",
        f"| Terraform-managed resources | {report['terraform_managed_resources']} |",
        f"| Manual review | {report['manual_review']} |",
        f"| Legacy StackSets remaining | {report['legacy_stacksets_remaining']} |",
        "",
        "## Notes",
        "",
    ]
    for note in report["notes"]:
        lines.append(f"- {note}")
    lines.append("")
    return "\n".join(lines)
