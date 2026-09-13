"""Analyze StackSets into a migration matrix. Never 1 StackSet = 1 module."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

from valeotf.migration.cfn import analyze_template, load_mapping
from valeotf.io import repo_root

PURPOSE_HINTS = {
    "ec2": "ec2-baseline",
    "rds": "rds-baseline",
    "backup": "backup",
    "ssm": "ssm",
    "kms": "kms",
    "iam": "iam",
    "config": "config",
    "log": "logging",
    "monitor": "monitoring",
    "vpc": "network",
    "network": "network",
    "scp": "organizations-scp",
    "guard": "security",
}

ORCHESTRATION_HINTS = ("stepfunction", "step-function", "codepipeline", "codebuild", "eventbridge", "stackset")


def _purpose(name: str) -> str:
    lowered = name.lower()
    for hint, module in PURPOSE_HINTS.items():
        if hint in lowered:
            return module
    return "unclassified"


def _recommended_action(name: str, analysis: dict[str, Any] | None) -> str:
    lowered = name.lower()
    if any(hint in lowered for hint in ORCHESTRATION_HINTS):
        return "REMOVE"
    if analysis and analysis.get("manual_review_count", 0) > 0:
        return "MANUAL REVIEW"
    purpose = _purpose(name)
    if purpose == "unclassified":
        return "MANUAL REVIEW"
    return "MIGRATE"


def analyze_stackset_catalog(path: Path | None = None, templates_dir: Path | None = None) -> list[dict[str, Any]]:
    root = repo_root()
    catalog_path = path or (root / "migration" / "stacksets" / "catalog.json")
    templates_dir = templates_dir or (root / "migration" / "cloudformation")
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    mapping = load_mapping(root)
    rows: list[dict[str, Any]] = []
    module_counts: dict[str, int] = defaultdict(int)

    for item in catalog.get("stacksets", []):
        name = item["name"]
        template_name = item.get("template")
        analysis = None
        if template_name:
            template_path = templates_dir / template_name
            if template_path.exists():
                analysis = analyze_template(template_path, mapping)
        purpose = item.get("purpose") or _purpose(name)
        analysis_action = _recommended_action(name, analysis)
        action = item.get("action") or analysis_action
        replacement = item.get("terraform_replacement")
        if not replacement and purpose != "unclassified":
            replacement = f"terraform/modules/{purpose}"
        if replacement:
            module_counts[replacement] += 1
        resources = []
        if analysis:
            resources = sorted({r["cfn_type"] for r in analysis["resources"] if r.get("cfn_type")})
        rows.append(
            {
                "stackset": name,
                "purpose": purpose,
                "resources": resources or item.get("resources") or [],
                "accounts": item.get("accounts", "unknown"),
                "regions": item.get("regions") or [],
                "terraform_replacement": replacement,
                "action": action,
                "status": item.get("status") or "PROPOSED",
                "template": template_name,
                "manual_review_count": (analysis or {}).get("manual_review_count", 0),
                "notes": item.get("notes") or "",
            }
        )

    for row in rows:
        replacement = row.get("terraform_replacement")
        if row["action"] == "REMOVE":
            continue
        if replacement and module_counts[replacement] > 1:
            row["action"] = "CONSOLIDATE"
            extra = f"Multiple StackSets map to {replacement}; do not create one module per StackSet."
            if row.get("manual_review_count"):
                extra += " Some resources still require MANUAL REVIEW inside that module."
            row["notes"] = (f"{row['notes']} {extra}" if row["notes"] else extra).strip()
    return rows


def matrix_markdown(rows: list[dict[str, Any]]) -> str:
    header = (
        "| StackSet | Purpose | Resources | Accounts | Regions | Terraform Replacement | Action | Status |\n"
        "|----------|---------|-----------|----------|---------|-----------------------|--------|--------|\n"
    )
    lines = [header]
    for row in rows:
        resources = ", ".join(row["resources"][:6])
        if len(row["resources"]) > 6:
            resources += ", …"
        regions = ", ".join(row["regions"])
        lines.append(
            f"| {row['stackset']} | {row['purpose']} | {resources} | {row['accounts']} | "
            f"{regions} | {row['terraform_replacement'] or ''} | {row['action']} | {row['status']} |\n"
        )
    return "".join(lines)
