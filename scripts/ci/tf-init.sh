#!/usr/bin/env bash
# Init a stack. Uses remote state when TF_BACKEND_CONFIG is set; otherwise -backend=false.
set -euo pipefail
STACK="${1:?stack path required e.g. terraform/stacks/account-baseline}"
if [[ -n "${TF_BACKEND_CONFIG:-}" ]]; then
  terraform -chdir="${STACK}" init -input=false -backend-config="${TF_BACKEND_CONFIG}"
else
  terraform -chdir="${STACK}" init -input=false -backend=false
fi
