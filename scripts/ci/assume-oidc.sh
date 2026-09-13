#!/usr/bin/env bash
# Assume GitLab OIDC into AWS. No-op when token or role is unset (validate-only CI).
set -euo pipefail
if [[ -z "${GITLAB_OIDC_TOKEN:-}" || -z "${AWS_ROLE_ARN:-}" ]]; then
  echo "OIDC skipped (GITLAB_OIDC_TOKEN or AWS_ROLE_ARN unset)."
  exit 0
fi
if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI missing; cannot assume OIDC role" >&2
  exit 1
fi
eval "$(aws sts assume-role-with-web-identity \
  --role-arn "${AWS_ROLE_ARN}" \
  --role-session-name "valeotf-${CI_JOB_STAGE:-ci}-${CI_JOB_ID:-local}" \
  --web-identity-token "${GITLAB_OIDC_TOKEN}" \
  --duration-seconds 3600 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text | awk '{printf "export AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s\n", $1,$2,$3}')"
echo "Assumed role via GitLab OIDC (role arn redacted from logs)."
