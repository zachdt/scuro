#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

echo "[1/5] Foundry unit + integration"
forge test --offline

echo "[2/5] Foundry invariants"
FOUNDRY_FUZZ_RUNS="${FOUNDRY_FUZZ_RUNS:-128}" forge test --match-path 'test/invariants/*.t.sol' --offline

echo "[3/5] Slot gas test lane"
forge test --match-path 'test/SlotMachineController.t.sol' --match-test 'test_Gas' --offline

echo "[4/5] Python slot EV lane"
if command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
import importlib.util
required = ("numpy", "polars")
missing = [name for name in required if importlib.util.find_spec(name) is None]
raise SystemExit(0 if not missing else 1)
PY
  then
    python3 -m unittest discover -s analysis/slot_ev/tests
    python3 -m analysis.slot_ev.report --preset all --samples 5000
  else
    echo "python dependencies missing; skipping EV analysis lane (see analysis/slot_ev/requirements.txt)"
  fi
else
  echo "python3 not installed; skipping EV analysis lane"
fi

echo "[5/5] Slither advisory"
"${ROOT}/script/check_slither.sh"
