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
ROOT="$(repo_root)"

mkdir -p "${OUTPUT_DIR}"

docker run --rm \
  -v "${ROOT}:/work" \
  -v "${OUTPUT_DIR}:/out" \
  amazonlinux:2023 \
  bash -lc "
set -euo pipefail
dnf install -y \
  clang \
  cmake \
  gcc \
  gcc-c++ \
  git \
  make \
  openssl-devel \
  perl-core \
  pkgconf-pkg-config \
  tar \
  xz
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
source /root/.cargo/env
rm -rf /tmp/foundry
git clone --depth 1 --branch '${FOUNDRY_GIT_REF}' https://github.com/foundry-rs/foundry /tmp/foundry
cargo install --locked --path /tmp/foundry/crates/forge --root /tmp/foundry-bin
cargo install --locked --path /tmp/foundry/crates/cast --root /tmp/foundry-bin
cargo install --locked --path /tmp/foundry/crates/anvil --root /tmp/foundry-bin
cp /tmp/foundry-bin/bin/forge /out/forge
cp /tmp/foundry-bin/bin/cast /out/cast
cp /tmp/foundry-bin/bin/anvil /out/anvil
"
