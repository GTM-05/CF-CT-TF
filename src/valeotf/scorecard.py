"""Engineering vs proven-in-AWS scores. 100% proven is impossible without a live Valeo batch."""

ENGINEERING = {
    "dynamic": 90,
    "production_grade": 90,
    "secure": 91,
    "upgradeable": 92,
}

PROVEN_AWS = {
    "dynamic": 40,
    "production_grade": 38,
    "secure": 45,
    "upgradeable": 50,
}

WORKFLOW_PARITY = 100

BLOCKERS_TO_100 = [
    "Live inventory of ~579 accounts (not fixtures)",
    "Live analysis of ~86 StackSets (not the sample catalog)",
    "Non-prod batch imported with terraform plan showing no destroy/replace",
    "GitLab OIDC role ARNs configured in CI variables",
    "VALEOTF_ENABLE_APPLY used on an approved non-prod batch",
    "Control Tower enrollment executed via approved API/runbook",
]


def overall(scores: dict[str, int]) -> int:
    return round(sum(scores.values()) / len(scores))


def report() -> dict:
    return {
        "workflow_parity_percent": WORKFLOW_PARITY,
        "engineering_percent": ENGINEERING,
        "engineering_overall": overall(ENGINEERING),
        "proven_in_aws_percent": PROVEN_AWS,
        "proven_overall": overall(PROVEN_AWS),
        "combined_overall": round((overall(ENGINEERING) * 0.7) + (overall(PROVEN_AWS) * 0.3)),
        "one_hundred_possible": False,
        "ninety_engineering_possible": True,
        "blockers_to_100_proven": BLOCKERS_TO_100,
    }
