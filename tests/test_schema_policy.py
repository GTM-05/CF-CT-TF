from pathlib import Path

from valeotf.policy import validate_policies
from valeotf.schema import validate_request_file, validate_request

ROOT = Path(__file__).resolve().parents[1]


def test_sample_new_account_request_is_valid() -> None:
    request, result = validate_request_file(ROOT / "requests" / "aws" / "dev" / "example-nonprod.yaml", root=ROOT)
    assert result.ok, result.errors
    policy = validate_policies(request, root=ROOT)
    assert policy.ok, policy.errors


def test_sample_adopt_request_is_valid() -> None:
    request, result = validate_request_file(ROOT / "requests" / "aws" / "test" / "example-existing-adopt.yaml", root=ROOT)
    assert result.ok, result.errors
    policy = validate_policies(request, root=ROOT)
    assert policy.ok, policy.errors


def test_rejects_aws_specific_top_level_fields() -> None:
    bad = {
        "AWSAccountName": "nope",
        "account": {
            "name": "example-account",
            "owner": "platform-team",
            "environment": "dev",
            "business_unit": "example",
            "requested_ou": "non-production",
        },
        "cloud": {"provider": "aws", "region": "eu-west-1"},
        "governance": {"control_tower": True},
        "tags": {"application": "x", "cost_center": "1"},
    }
    result = validate_request(bad, root=ROOT)
    assert not result.ok


def test_policy_rejects_unapproved_region() -> None:
    request, _ = validate_request_file(ROOT / "requests" / "aws" / "dev" / "example-nonprod.yaml", root=ROOT)
    request["cloud"]["region"] = "us-east-1"
    policy = validate_policies(request, root=ROOT)
    assert not policy.ok
    assert any("us-east-1" in err for err in policy.errors)


def test_policy_requires_backup_in_prod() -> None:
    request, _ = validate_request_file(ROOT / "requests" / "aws" / "dev" / "example-nonprod.yaml", root=ROOT)
    request["account"]["environment"] = "prod"
    request["account"]["requested_ou"] = "production"
    request["baseline"]["backup"] = False
    policy = validate_policies(request, root=ROOT)
    assert not policy.ok
    assert any("backup" in err for err in policy.errors)
