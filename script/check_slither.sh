#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v slither >/dev/null 2>&1; then
  echo "slither is not installed; skipping advisory static-analysis lane"
  exit 0
fi

slither . --config-file slither.config.json
