#!/usr/bin/env bash
# Control Tower enrollment adapter. Read-only unless VALEOTF_ENABLE_CT_ENROLL=true.
# Does not invent Terraform resources.
set -euo pipefail
ACCOUNT_ID="${1:?account id required}"

echo "Control Tower adapter: account ${ACCOUNT_ID}"
echo "This maps to the legacy Control Tower Account Factory step."

if [[ "${VALEOTF_ENABLE_CT_ENROLL:-false}" != "true" ]]; then
  echo "DRY-RUN: not calling Register/Enroll APIs. Set VALEOTF_ENABLE_CT_ENROLL=true after approval."
  exit 0
fi

aws controltower list-enabled-controls --target-identifier "${ACCOUNT_ID}" --output json
echo "Enrollment mutation must be performed with an approved Control Tower API/runbook, not a fake Terraform resource."
