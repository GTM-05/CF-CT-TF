from pathlib import Path

from valeotf.arc import assert_ci_matches_arc
from valeotf.scorecard import ENGINEERING, WORKFLOW_PARITY, report

ROOT = Path(__file__).resolve().parents[1]


def test_no_administrator_access_in_modules() -> None:
    hits = []
    for path in (ROOT / "terraform" / "modules").rglob("*.tf"):
        text = path.read_text(encoding="utf-8")
        if "AdministratorAccess" in text:
            hits.append(str(path))
    assert hits == []


def test_apply_role_has_permission_boundary() -> None:
    iam = (ROOT / "terraform" / "modules" / "iam" / "main.tf").read_text(encoding="utf-8")
    assert "permissions_boundary" in iam


def test_gitlab_includes_generated_stages() -> None:
    ci = (ROOT / ".gitlab-ci.yml").read_text(encoding="utf-8")
    assert "pipeline/generated/stages.yml" in ci
    assert "Jobs/Secret-Detection.gitlab-ci.yml" in ci


def test_engineering_scorecard_is_at_least_90() -> None:
    assert WORKFLOW_PARITY == 100
    assert min(ENGINEERING.values()) >= 90
    data = report()
    assert data["one_hundred_possible"] is False
    assert data["ninety_engineering_possible"] is True


def test_generated_ci_matches_arc() -> None:
    assert_ci_matches_arc(ROOT)
