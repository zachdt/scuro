#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=script/aws/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd docker

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <output-dir>" >&2
  exit 1
fi

OUTPUT_DIR="$1"
FOUNDRY_GIT_REF="${FOUNDRY_GIT_REF:-v1.5.1}"
FOUNDRY_VERSION="${FOUNDRY_GIT_REF#v}"
FOUNDRY_TAG="v${FOUNDRY_VERSION}"
ASSET_NAME="foundry_${FOUNDRY_TAG}_linux_amd64.tar.gz"
ASSET_URL="https://github.com/foundry-rs/foundry/releases/download/${FOUNDRY_TAG}/${ASSET_NAME}"
ROOT="$(repo_root)"

mkdir -p "${OUTPUT_DIR}"

docker run --rm \
  -v "${ROOT}:/work" \
  -v "${OUTPUT_DIR}:/out" \
  amazonlinux:2023 \
  bash -lc "
set -euo pipefail
dnf install -y \
  ca-certificates \
  curl \
  tar \
  xz
rm -rf /tmp/foundry /root/.svm
mkdir -p /tmp/foundry
curl --proto '=https' --tlsv1.2 -sSfL \"${ASSET_URL}\" -o /tmp/foundry.tar.gz
tar -xzf /tmp/foundry.tar.gz -C /tmp/foundry
cp /tmp/foundry/forge /out/forge
cp /tmp/foundry/cast /out/cast
cp /tmp/foundry/anvil /out/anvil
chmod +x /out/forge /out/cast /out/anvil
{
  /out/forge --version
  /out/cast --version
  /out/anvil --version
} | tee /out/foundry-versions.txt
cd /work
PATH=\"/out:${PATH}\" /out/forge build >/dev/null
if [[ -d /root/.svm ]]; then
  cp -R /root/.svm /out/svm
fi
"
