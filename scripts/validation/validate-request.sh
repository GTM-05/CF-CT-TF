#!/usr/bin/env bash
set -euo pipefail
valeotf validate-request "${1:?request yaml}"
