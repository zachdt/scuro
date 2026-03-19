#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

forge snapshot \
  --match-path 'test/SlotMachineController.t.sol' \
  --match-test 'test_Gas' \
  --snap .gas-snapshot-slot
