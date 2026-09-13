#!/usr/bin/env bash
set -euo pipefail
valeotf analyze-stacksets --write
valeotf generate-import-map --write
valeotf migration-report --write
