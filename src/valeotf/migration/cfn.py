"""CloudFormation template parsing and Terraform mapping."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml

from valeotf.io import repo_root

ACTIONS = ("MIGRATE", "CONSOLIDATE", "RETAIN", "REMOVE", "MANUAL REVIEW", "MANUAL_REVIEW_REQUIRED")


def load_mapping(root: Path | None = None) -> dict[str, Any]:
    bundled = Path(__file__).resolve().parent.parent / "data" / "cfn-to-terraform.json"
    override = (root or repo_root()) / "migration" / "mappings" / "cfn-to-terraform.json"
    path = override if override.exists() else bundled
    return json.loads(path.read_text(encoding="utf-8"))


def parse_template(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    if path.suffix in {".json"}:
        template = json.loads(text)
    else:
        template = yaml.load(text, Loader=_CfnLoader)
    if not isinstance(template, dict):
        raise ValueError(f"{path} is not a CloudFormation template mapping")
    return template


class _CfnLoader(yaml.SafeLoader):
    """Accept CloudFormation YAML tags such as !Ref and !GetAtt without executing them."""


def _cfn_tag_constructor(loader: yaml.SafeLoader, tag_suffix: str, node: yaml.Node) -> Any:
    if isinstance(node, yaml.ScalarNode):
        return {f"Fn::{tag_suffix}": loader.construct_scalar(node)}
    if isinstance(node, yaml.SequenceNode):
        return {f"Fn::{tag_suffix}": loader.construct_sequence(node)}
    if isinstance(node, yaml.MappingNode):
        return {f"Fn::{tag_suffix}": loader.construct_mapping(node)}
    return {f"Fn::{tag_suffix}": None}


_CfnLoader.add_multi_constructor("!", _cfn_tag_constructor)


def analyze_template(path: Path, mapping: dict[str, Any] | None = None) -> dict[str, Any]:
    template = parse_template(path)
    mapping = mapping or load_mapping()
    resources = template.get("Resources") or {}
    parameters = template.get("Parameters") or {}
    outputs = template.get("Outputs") or {}
    analyzed_resources = []
    for logical_id, spec in resources.items():
        rtype = spec.get("Type") if isinstance(spec, dict) else None
        mapped = mapping.get(rtype or "", {})
        terraform = mapped.get("terraform")
        action = mapped.get("action_default")
        if not mapped:
            action = "MANUAL_REVIEW_REQUIRED"
        analyzed_resources.append(
            {
                "logical_id": logical_id,
                "cfn_type": rtype,
                "terraform": terraform,
                "action": action,
                "depends_on": (spec or {}).get("DependsOn") if isinstance(spec, dict) else None,
                "notes": mapped.get("notes"),
                "has_secret_parameters": _looks_like_secret(spec) if isinstance(spec, dict) else False,
            }
        )
    return {
        "template": str(path),
        "description": template.get("Description"),
        "parameters": list(parameters.keys()),
        "outputs": list(outputs.keys()),
        "resources": analyzed_resources,
        "iam_capabilities_likely": any(
            (item.get("cfn_type") or "").startswith("AWS::IAM::") for item in analyzed_resources
        ),
        "manual_review_count": sum(
            1
            for item in analyzed_resources
            if item["action"] in {"MANUAL REVIEW", "MANUAL_REVIEW", "MANUAL_REVIEW_REQUIRED"}
        ),
    }


def _looks_like_secret(spec: dict[str, Any]) -> bool:
    blob = json.dumps(spec)
    needles = ("Password", "Secret", "PrivateKey", "SecretString")
    return any(needle in blob for needle in needles)
