"""Flag destroy/replace and high-risk updates in terraform show -json plans."""

from __future__ import annotations

from typing import Any

HIGH_RISK_PREFIXES = (
    "aws_iam_",
    "aws_security_group",
    "aws_kms_",
    "aws_vpc",
    "aws_subnet",
    "aws_route",
    "aws_organizations_policy",
)


def analyze_plan(plan: dict[str, Any]) -> dict[str, Any]:
    changes = []
    resource_changes = plan.get("resource_changes") or []
    for change in resource_changes:
        actions = (change.get("change") or {}).get("actions") or []
        address = change.get("address") or ""
        rtype = change.get("type") or ""
        high_risk = any(rtype.startswith(prefix) for prefix in HIGH_RISK_PREFIXES)
        destructive = bool(set(actions) & {"delete", "replace"})
        changes.append(
            {
                "address": address,
                "type": rtype,
                "actions": actions,
                "destructive": destructive,
                "high_risk": high_risk and ("update" in actions or destructive),
            }
        )
    destroys = [c for c in changes if "delete" in c["actions"] and "create" not in c["actions"]]
    replaces = [c for c in changes if "replace" in c["actions"] or c["actions"] == ["delete", "create"]]
    high_risk = [c for c in changes if c["high_risk"]]
    must_stop = bool(destroys or replaces)
    return {
        "must_stop": must_stop,
        "destroy_count": len(destroys),
        "replace_count": len(replaces),
        "high_risk_count": len(high_risk),
        "destroys": destroys,
        "replaces": replaces,
        "high_risk": high_risk,
        "message": (
            "STOP: terraform plan proposes destroy or replace. Manual investigation required."
            if must_stop
            else "No destroy/replace detected."
        ),
    }
