#!/usr/bin/env bash
set -euo pipefail
# Plan only. Never apply from this script.
terraform -chdir=terraform/stacks/account-baseline init -backend=false
terraform -chdir=terraform/stacks/account-baseline validate -var-file=terraform.tfvars.example
terraform -chdir=terraform/stacks/account-baseline plan -var-file=terraform.tfvars.example
