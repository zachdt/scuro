#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"
require_cmd terraform

cd "$(terraform_dir)"
terraform init
terraform apply "$@"
