"""valeotf CLI: discover → map → import candidates → plan review. Apply is never implicit."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import click

from valeotf import __version__
from valeotf.inventory.collector import collect_accounts_metadata, collect_from_directory, collect_aws_organizations
from valeotf.io import dump_json, dump_text, load_json, load_yaml, repo_root
from valeotf.migration.cfn import analyze_template, load_mapping
from valeotf.migration.destructive import analyze_plan
from valeotf.migration.imports import generate_import_map
from valeotf.migration.reports import build_report, report_markdown
from valeotf.migration.stacksets import analyze_stackset_catalog, matrix_markdown
from valeotf.arc import GITLAB_SEQUENCE, LEGACY_TO_MODERN, assert_ci_matches_arc, gitlab_stages, next_stages_for_request
from valeotf.ci_gen import write_generated_ci
from valeotf.scorecard import report as scorecard_report
from valeotf.policy import validate_policies
from valeotf.schema import validate_request_file
from valeotf.terraform_gen import request_to_tfvars, state_key, write_backend_hcl, write_tfvars


@click.group()
@click.version_option(__version__)
def main() -> None:
    """Valeo Terraform Control Tower platform."""


@main.command("arc")
@click.option("--request", "request_file", default=None)
def arc_cmd(request_file: str | None) -> None:
    """Print the same ordered factory arc as the legacy platform."""
    payload = {
        "gitlab_sequence": list(GITLAB_SEQUENCE),
        "declared_gitlab_stages": gitlab_stages(),
        "legacy_to_modern": LEGACY_TO_MODERN,
    }
    if request_file:
        request, result = validate_request_file(Path(request_file))
        result.raise_for_errors()
        payload["stages_for_request"] = next_stages_for_request(request)
    click.echo(json.dumps(payload, indent=2))


@main.command("assert-arc")
def assert_arc_cmd() -> None:
    """Fail if GitLab stages drift from pipeline/arc.yaml (same workflow contract)."""
    assert_ci_matches_arc()
    click.echo("OK: GitLab stages match pipeline/arc.yaml")


@main.command("generate-ci")
@click.option("--check", is_flag=True, help="Exit 1 if generated stages.yml is stale.")
def generate_ci_cmd(check: bool) -> None:
    """Generate pipeline/generated/stages.yml from pipeline/arc.yaml."""
    if check:
        assert_ci_matches_arc()
        click.echo("OK: generated CI is up to date")
        return
    path = write_generated_ci()
    click.echo(f"Wrote {path}")


@main.command("scorecard")
def scorecard_cmd() -> None:
    """Print engineering vs proven-in-AWS scores. 100% proven requires a live batch."""
    click.echo(json.dumps(scorecard_report(), indent=2))


@main.group("inventory")
def inventory_group() -> None:
    """Discover what exists. This is not Terraform state and not Control Tower enrollment."""


@inventory_group.command("accounts")
@click.option("--live", is_flag=True, help="Call AWS Organizations (read-only). Default uses fixtures.")
def inventory_accounts(live: bool) -> None:
    accounts = collect_aws_organizations(dry_run=not live) if live else collect_from_directory()
    click.echo(json.dumps(collect_accounts_metadata(accounts), indent=2))


@inventory_group.command("resources")
def inventory_resources() -> None:
    accounts = collect_from_directory()
    click.echo(json.dumps(accounts, indent=2))


@main.command("inventory")
def inventory_all() -> None:
    accounts = collect_from_directory()
    click.echo(json.dumps({"count": len(accounts), "accounts": accounts}, indent=2))


@main.command("analyze-stacksets")
@click.option("--write", "do_write", is_flag=True)
def analyze_stacksets_cmd(do_write: bool) -> None:
    rows = analyze_stackset_catalog()
    markdown = matrix_markdown(rows)
    click.echo(markdown)
    if do_write:
        root = repo_root()
        dump_json(root / "migration" / "reports" / "stackset-matrix.json", rows)
        dump_text(root / "migration" / "reports" / "stackset-matrix.md", markdown)


@main.command("analyze-template")
@click.argument("template")
def analyze_template_cmd(template: str) -> None:
    path = Path(template)
    if not path.exists():
        path = repo_root() / "migration" / "cloudformation" / template
    result = analyze_template(path)
    click.echo(json.dumps(result, indent=2))


@main.command("generate-import-map")
@click.option("--write", "do_write", is_flag=True)
def generate_import_map_cmd(do_write: bool) -> None:
    accounts = collect_from_directory()
    mapping = load_mapping()
    candidates = generate_import_map(accounts, mapping)
    click.echo(json.dumps(candidates, indent=2))
    if do_write:
        dump_json(repo_root() / "migration" / "imports" / "import-map.json", candidates)


@main.command("generate-terraform")
@click.argument("request_file")
def generate_terraform_cmd(request_file: str) -> None:
    request, schema_result = validate_request_file(Path(request_file))
    schema_result.raise_for_errors()
    policy = validate_policies(request)
    if not policy.ok:
        raise click.ClickException("\n".join(policy.errors))
    tfvars = request_to_tfvars(request)
    root = repo_root()
    out = root / "terraform" / "stacks" / "account-baseline" / "generated.auto.tfvars.json"
    dump_json(out, tfvars)
    account_id = tfvars["account_id"] or "unassigned"
    write_backend_hcl(
        root / "terraform" / "stacks" / "account-baseline" / "backend.generated.hcl.example",
        bucket="REPLACE_STATE_BUCKET",
        key=state_key(account_id, tfvars["environment"], tfvars["region"], "baseline"),
        region=tfvars["region"],
        dynamodb_table="REPLACE_LOCK_TABLE",
    )
    click.echo(f"Wrote {out}")
    click.echo("Backend example written with placeholders. Do not commit real bucket names if they are secrets.")


@main.command("validate-request")
@click.argument("request_file")
def validate_request_cmd(request_file: str) -> None:
    request, schema_result = validate_request_file(Path(request_file))
    if not schema_result.ok:
        raise click.ClickException("Schema validation failed:\n" + "\n".join(schema_result.errors))
    policy = validate_policies(request)
    for warning in policy.warnings:
        click.echo(f"WARNING: {warning}", err=True)
    if not policy.ok:
        raise click.ClickException("Policy validation failed:\n" + "\n".join(policy.errors))
    click.echo("OK: schema and policy validation passed")


@main.command("plan")
@click.option("--chdir", default="terraform/stacks/account-baseline")
@click.option("--plan-out", default="tfplan")
def plan_cmd(chdir: str, plan_out: str) -> None:
    _require_terraform()
    cwd = repo_root() / chdir
    subprocess.run(["terraform", "init", "-backend=false", "-input=false"], cwd=cwd, check=True)
    subprocess.run(["terraform", "validate"], cwd=cwd, check=True)
    subprocess.run(
        ["terraform", "plan", "-input=false", f"-out={plan_out}"],
        cwd=cwd,
        check=True,
    )
    show = subprocess.run(
        ["terraform", "show", "-json", plan_out],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )
    analysis = analyze_plan(json.loads(show.stdout))
    click.echo(json.dumps(analysis, indent=2))
    if analysis["must_stop"]:
        raise SystemExit(2)


@main.command("apply")
@click.option("--chdir", default="terraform/stacks/account-baseline")
@click.option("--plan-out", default="tfplan")
@click.option("--approve", is_flag=True, help="Required. Apply never runs without this flag AND a reviewed plan.")
def apply_cmd(chdir: str, plan_out: str, approve: bool) -> None:
    if not approve:
        raise click.ClickException("Refusing to apply. Pass --approve after a reviewed plan with no unexpected destroy/replace.")
    _require_terraform()
    cwd = repo_root() / chdir
    plan_path = cwd / plan_out
    if not plan_path.exists():
        raise click.ClickException("No saved plan. Run valeotf plan first.")
    show = subprocess.run(
        ["terraform", "show", "-json", plan_out],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )
    analysis = analyze_plan(json.loads(show.stdout))
    if analysis["must_stop"]:
        raise click.ClickException(analysis["message"])
    click.echo("Apply is gated. This CLI still requires GitLab manual approval for production.")
    subprocess.run(["terraform", "apply", "-input=false", plan_out], cwd=cwd, check=True)


@main.command("migration-status")
def migration_status_cmd() -> None:
    report = _current_report()
    click.echo(json.dumps(report, indent=2))


@main.command("migration-report")
@click.option("--write", "do_write", is_flag=True)
def migration_report_cmd(do_write: bool) -> None:
    report = _current_report()
    markdown = report_markdown(report)
    click.echo(markdown)
    if do_write:
        root = repo_root()
        dump_json(root / "migration" / "reports" / "migration-report.json", report)
        dump_text(root / "migration" / "reports" / "migration-report.md", markdown)


@main.command("check-plan")
@click.argument("plan_json")
def check_plan_cmd(plan_json: str) -> None:
    plan = load_json(Path(plan_json))
    analysis = analyze_plan(plan)
    click.echo(json.dumps(analysis, indent=2))
    if analysis["must_stop"]:
        raise SystemExit(2)


def _current_report() -> dict:
    accounts = collect_from_directory()
    rows = analyze_stackset_catalog()
    mapping = load_mapping()
    candidates = generate_import_map(accounts, mapping)
    return build_report(accounts=accounts, stackset_rows=rows, import_candidates=candidates)


def _require_terraform() -> None:
    if shutil.which("terraform") is None:
        raise click.ClickException("terraform is not installed on PATH")


if __name__ == "__main__":
    sys.exit(main())
