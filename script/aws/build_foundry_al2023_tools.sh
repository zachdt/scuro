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
REPO_URL="https://github.com/foundry-rs/foundry.git"

mkdir -p "${OUTPUT_DIR}"

docker run --rm \
  --platform linux/amd64 \
  -v "${OUTPUT_DIR}:/out" \
  amazonlinux:2023 \
  bash -lc "
set -euo pipefail
dnf install -y \
  ca-certificates \
  clang \
  cmake \
  gcc \
  gcc-c++ \
  git \
  gzip \
  make \
  openssl-devel \
  perl-core \
  pkgconf-pkg-config \
  tar \
  xz
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
source /root/.cargo/env
rm -rf /tmp/foundry /root/.svm
git clone --depth 1 --branch \"${FOUNDRY_TAG}\" \"${REPO_URL}\" /tmp/foundry
cargo build --locked --release --bins --manifest-path /tmp/foundry/Cargo.toml
cp /tmp/foundry/target/release/forge /out/forge
cp /tmp/foundry/target/release/cast /out/cast
cp /tmp/foundry/target/release/anvil /out/anvil
chmod +x /out/forge /out/cast /out/anvil
{
  echo \"Requested Foundry Tag: ${FOUNDRY_TAG}\"
  echo \"Build Source: ${REPO_URL}#${FOUNDRY_TAG}\"
  /out/forge --version
  /out/cast --version
  /out/anvil --version
} | tee /out/foundry-versions.txt
if [[ -d /root/.svm ]]; then
  cp -R /root/.svm /out/svm
fi
"
