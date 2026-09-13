from valeotf.arc import GITLAB_SEQUENCE, gitlab_stages, load_arc, next_stages_for_request
from valeotf.io import load_yaml
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_gitlab_arc_matches_legacy_order() -> None:
    stages = gitlab_stages()
    assert stages[:6] == [
        "request-validate",
        "security",
        "account-factory",
        "scp",
        "baseline",
        "resources",
    ]
    assert GITLAB_SEQUENCE[0] == "request-validate"
    assert "scp" in GITLAB_SEQUENCE
    assert GITLAB_SEQUENCE.index("account-factory") < GITLAB_SEQUENCE.index("scp")
    assert GITLAB_SEQUENCE.index("scp") < GITLAB_SEQUENCE.index("baseline")


def test_arc_yaml_maps_legacy_factory_steps() -> None:
    arc = load_arc(ROOT)
    ids = [item["id"] for item in arc["stages"]]
    assert "account-factory" in ids
    assert "scp" in ids
    assert "baseline" in ids
    stacks = [item.get("terraform_stack") for item in arc["stages"] if item.get("terraform_stack")]
    assert stacks == [
        "terraform/stacks/account-vending",
        "terraform/stacks/organization",
        "terraform/stacks/account-baseline",
        "terraform/stacks/account-resources",
    ]


def test_adopt_keeps_same_factory_order() -> None:
    request = load_yaml(ROOT / "requests" / "aws" / "test" / "example-existing-adopt.yaml")
    stages = next_stages_for_request(request)
    assert stages == list(GITLAB_SEQUENCE)
    assert stages.index("account-factory") < stages.index("scp") < stages.index("baseline")


def test_gitlab_ci_matches_arc_yaml() -> None:
    from valeotf.arc import assert_ci_matches_arc

    assert_ci_matches_arc(ROOT)
