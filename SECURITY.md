# Security

## Never commit

AWS access keys, secret values, passwords, AD passwords, Secrets Manager values, private keys.

## How credentials work

- GitLab OIDC or short-lived runner roles (preferred)
- STS AssumeRole into member accounts
- Separate plan and apply roles when the organization can issue them
- No access keys in Terraform files

## Secrets in modules

EC2 baseline accepts `secret_arn` only (must start with `arn:`). Outputs never include secret payloads. CI must use `-json` plan checks without printing sensitive values; GitLab `mask` variables for any token.

## Policy

`policies/security/security.yaml` requires encryption and monitoring. Wildcard trust on the Terraform execution role is prohibited by review, not by silently rewriting AWS.

## Control Tower

Do not bypass Control Tower guardrails with Terraform. SCP changes in production require the GitLab approval job.
