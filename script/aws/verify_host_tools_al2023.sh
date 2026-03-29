#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd docker

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <tools-dir> [output-log]" >&2
  exit 1
fi

TOOLS_DIR="$1"
OUTPUT_LOG="${2:-}"

for tool in bun forge cast anvil; do
  if [[ ! -x "${TOOLS_DIR}/bin/${tool}" ]]; then
    echo "expected executable ${TOOLS_DIR}/bin/${tool}" >&2
    exit 1
  fi
done

run_check() {
  docker run --rm \
    --platform linux/amd64 \
    -v "${TOOLS_DIR}:/tools:ro" \
    amazonlinux:2023 \
    bash -lc '
set -euo pipefail
echo "Amazon Linux 2023 host tool compatibility"
echo
for tool in bun forge cast anvil; do
  echo "==== ${tool} ===="
  "/tools/bin/${tool}" --version
  echo
done
'
}

if [[ -n "${OUTPUT_LOG}" ]]; then
  mkdir -p "$(dirname "${OUTPUT_LOG}")"
  run_check | tee "${OUTPUT_LOG}"
else
  run_check
fi
