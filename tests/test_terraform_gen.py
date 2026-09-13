from pathlib import Path

from valeotf.io import load_yaml
from valeotf.terraform_gen import request_to_tfvars, state_key

ROOT = Path(__file__).resolve().parents[1]


def test_request_to_tfvars_uses_neutral_fields() -> None:
    request = load_yaml(ROOT / "requests" / "aws" / "dev" / "example-nonprod.yaml")
    tfvars = request_to_tfvars(request)
    assert "AWSAccountName" not in tfvars
    assert tfvars["account_name"] == "example-nonprod"
    assert tfvars["dry_run"] is True
    assert tfvars["region"] == "eu-west-1"


def test_state_key_separates_blast_radius() -> None:
    key = state_key("123456789012", "prod", "eu-west-1", "baseline")
    assert key == "aws/account-123456789012/prod/eu-west-1/baseline.tfstate"
