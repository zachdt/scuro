#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

forge build --offline >/dev/null
ruby script/docs/generate_protocol_docs_metadata.rb >/dev/null
ruby script/docs/check_sdk_docs_coverage.rb
node script/docs/smoke_manifest_node.mjs

if command -v rustc >/dev/null 2>&1; then
  rustc script/docs/smoke_manifest_rust.rs -o /tmp/scuro_manifest_smoke
  /tmp/scuro_manifest_smoke
else
  echo "rustc unavailable; skipped rust manifest smoke"
fi
