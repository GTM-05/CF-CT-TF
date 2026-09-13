from pathlib import Path

from valeotf.inventory.collector import collect_from_directory
from valeotf.migration.cfn import analyze_template, load_mapping
from valeotf.migration.destructive import analyze_plan
from valeotf.migration.imports import generate_import_map
from valeotf.migration.stacksets import analyze_stackset_catalog

ROOT = Path(__file__).resolve().parents[1]


def test_iam_role_maps_to_aws_iam_role() -> None:
    mapping = load_mapping(ROOT)
    assert mapping["AWS::IAM::Role"]["terraform"] == "aws_iam_role"


def test_analyze_ec2_baseline_flags_manual_review_types() -> None:
    analysis = analyze_template(
        ROOT / "migration" / "cloudformation" / "ec2-baseline-stack.template.yaml",
        load_mapping(ROOT),
    )
    types = {item["cfn_type"]: item["action"] for item in analysis["resources"]}
    assert types["AWS::IAM::Role"] == "MIGRATE"
    assert types["AWS::Lambda::Function"] == "MANUAL_REVIEW"
    assert types["AWS::SecretsManager::Secret"] == "MANUAL_REVIEW"
    assert analysis["manual_review_count"] >= 2


def test_stacksets_are_consolidated_not_one_module_each() -> None:
    rows = analyze_stackset_catalog()
    by_name = {row["stackset"]: row for row in rows}
    assert by_name["CustomControlTower-ec2-users-stack"]["action"] == "CONSOLIDATE"
    assert by_name["CustomControlTower-ec2-baseline-stack"]["action"] == "CONSOLIDATE"
    assert "ec2-baseline" in (by_name["CustomControlTower-ec2-users-stack"]["terraform_replacement"] or "")
    assert by_name["CustomControlTower-codepipeline-wrapper"]["action"] == "REMOVE"
    assert len(rows) < 86


def test_import_map_blocks_cloudformation_owned() -> None:
    accounts = collect_from_directory()
    candidates = generate_import_map(accounts, load_mapping(ROOT))
    cf_owned = [c for c in candidates if c["resource_id"] == "example-baseline-role"]
    ready = [c for c in candidates if c["resource_id"] == "valeotf-ready-role"]
    assert cf_owned[0]["migration_status"] == "MANUAL_REVIEW"
    assert cf_owned[0]["import_command"] is None
    assert ready[0]["migration_status"] == "READY_FOR_IMPORT"
    lambdas = [c for c in candidates if c["inventory_key"] == "lambda_functions"]
    assert lambdas[0]["migration_status"] == "MANUAL_REVIEW"


def test_destructive_plan_must_stop() -> None:
    plan = {
        "resource_changes": [
            {
                "address": "aws_iam_role.example",
                "type": "aws_iam_role",
                "change": {"actions": ["delete"]},
            }
        ]
    }
    result = analyze_plan(plan)
    assert result["must_stop"] is True
    assert result["destroy_count"] == 1


def test_non_destructive_plan_ok() -> None:
    plan = {
        "resource_changes": [
            {
                "address": "aws_ssm_parameter.x",
                "type": "aws_ssm_parameter",
                "change": {"actions": ["create"]},
            }
        ]
    }
    result = analyze_plan(plan)
    assert result["must_stop"] is False
