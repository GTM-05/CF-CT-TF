"""Ordered platform arc. Must match pipeline/arc.yaml and GitLab stages."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from valeotf.io import load_yaml, repo_root

GITLAB_SEQUENCE = (
    "request-validate",
    "security",
    "account-factory",
    "scp",
    "baseline",
    "resources",
    "approval",
    "apply",
)

LEGACY_TO_MODERN = {
    "AWS Service Catalog": "Git account request YAML/JSON + schema/policy",
    "Valeo Account Factory": "terraform/stacks/account-vending",
    "CloudFormation Wrapper": "valeotf generate-terraform",
    "Control Tower Account Factory": "AWS Control Tower + adapter (no fake resources)",
    "EventBridge": "GitLab pipeline trigger on Git events",
    "Step Functions": "GitLab stage DAG + Terraform graph",
    "CodePipeline": "GitLab CI/CD",
    "CodeBuild": "GitLab runner",
    "SCP Step Function": "terraform/stacks/organization",
    "StackSet Step Function": "terraform/stacks/account-baseline",
    "CloudFormation StackSets": "consolidated Terraform modules",
    "CloudFormation Stacks": "Terraform-managed resources + per-account state",
}


def load_arc(root: Path | None = None) -> dict[str, Any]:
    return load_yaml((root or repo_root()) / "pipeline" / "arc.yaml")


def gitlab_stages(arc: dict[str, Any] | None = None) -> list[str]:
    arc = arc or load_arc()
    stages: list[str] = []
    for item in arc["stages"]:
        stage = item.get("gitlab_stage")
        if stage and stage not in stages:
            stages.append(stage)
    for extra in ("approval", "apply"):
        if extra not in stages:
            stages.append(extra)
    return stages


def stacks_in_order(arc: dict[str, Any] | None = None) -> list[str]:
    arc = arc or load_arc()
    return [item["terraform_stack"] for item in arc["stages"] if item.get("terraform_stack")]


def next_stages_for_request(_request: dict[str, Any]) -> list[str]:
    """Same factory order for new and adopt. Vending is a no-op when existing_account_id is set."""
    return list(GITLAB_SEQUENCE)


def generated_stages_path(root: Path | None = None) -> Path:
    return (root or repo_root()) / "pipeline" / "generated" / "stages.yml"


def gitlab_ci_stages(root: Path | None = None) -> list[str]:
    root = root or repo_root()
    generated = load_yaml(generated_stages_path(root))
    return list((generated or {}).get("stages") or [])


def assert_ci_matches_arc(root: Path | None = None) -> None:
    root = root or repo_root()
    expected = gitlab_stages(load_arc(root))
    actual = gitlab_ci_stages(root)
    if actual != expected:
        raise ValueError(
            "Generated GitLab stages drifted from pipeline/arc.yaml.\n"
            f"  arc:    {expected}\n"
            f"  gitlab: {actual}\n"
            "Run: valeotf generate-ci"
        )
    from valeotf.ci_gen import assert_generated_ci

    assert_generated_ci(root)
