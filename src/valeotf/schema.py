"""Cloud-neutral account request schema validation."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

from valeotf.io import load_yaml, repo_root


@dataclass
class ValidationResult:
    ok: bool
    errors: list[str]

    def raise_for_errors(self) -> None:
        if not self.ok:
            raise ValueError("\n".join(self.errors))


def schema_path(root: Path | None = None) -> Path:
    return (root or repo_root()) / "schemas" / "account-request.schema.yaml"


def load_schema(root: Path | None = None) -> dict[str, Any]:
    return load_yaml(schema_path(root))


def validate_request(request: dict[str, Any], root: Path | None = None) -> ValidationResult:
    schema = load_schema(root)
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(request), key=lambda err: list(err.path))
    messages = [f"{'/'.join(str(p) for p in err.path) or '<root>'}: {err.message}" for err in errors]
    return ValidationResult(ok=not messages, errors=messages)


def validate_request_file(path: Path, root: Path | None = None) -> tuple[dict[str, Any], ValidationResult]:
    request = load_yaml(path)
    if not isinstance(request, dict):
        return {}, ValidationResult(ok=False, errors=["request must be a mapping"])
    return request, validate_request(request, root=root)
