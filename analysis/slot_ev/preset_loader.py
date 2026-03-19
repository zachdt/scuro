from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
DEFAULT_FIXTURE_PATH = ROOT / "presets" / "sample_presets.json"

REQUIRED_FIELDS = {
    "presetId",
    "volatilityTier",
    "configHash",
    "reelCount",
    "rowCount",
    "waysMode",
    "minStake",
    "maxStake",
    "maxPayoutMultiplierBps",
    "symbolIds",
    "wildSymbolId",
    "scatterSymbolId",
    "bonusSymbolId",
    "jackpotSymbolId",
    "reelWeightOffsets",
    "reelSymbolIds",
    "reelSymbolWeights",
    "paytableSymbolIds",
    "paytableMatchCounts",
    "paytableMultiplierBps",
    "freeSpinTriggerCount",
    "freeSpinAwardCounts",
    "maxFreeSpins",
    "maxRetriggers",
    "freeSpinMultiplierBps",
    "pickTriggerCount",
    "maxPickReveals",
    "pickAwardMultiplierBps",
    "holdTriggerCount",
    "holdBoardSize",
    "initialRespins",
    "maxRespins",
    "holdValueMultiplierBps",
    "jackpotTierIds",
    "jackpotAwardMultiplierBps",
    "jackpotTierWeights",
    "maxTotalEvents"
}

INT_FIELDS = {
    "presetId",
    "volatilityTier",
    "reelCount",
    "rowCount",
    "waysMode",
    "minStake",
    "maxStake",
    "maxPayoutMultiplierBps",
    "wildSymbolId",
    "scatterSymbolId",
    "bonusSymbolId",
    "jackpotSymbolId",
    "freeSpinTriggerCount",
    "maxFreeSpins",
    "maxRetriggers",
    "freeSpinMultiplierBps",
    "pickTriggerCount",
    "maxPickReveals",
    "holdTriggerCount",
    "holdBoardSize",
    "initialRespins",
    "maxRespins",
    "maxTotalEvents"
}

ARRAY_FIELDS = {
    "symbolIds",
    "reelWeightOffsets",
    "reelSymbolIds",
    "reelSymbolWeights",
    "paytableSymbolIds",
    "paytableMatchCounts",
    "paytableMultiplierBps",
    "freeSpinAwardCounts",
    "pickAwardMultiplierBps",
    "holdValueMultiplierBps",
    "jackpotTierIds",
    "jackpotAwardMultiplierBps",
    "jackpotTierWeights"
}


def _to_int(value: Any) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return int(value, 0)
    raise TypeError(f"unsupported integer value: {value!r}")


def _normalize_preset(raw: dict[str, Any]) -> dict[str, Any]:
    missing = REQUIRED_FIELDS - raw.keys()
    if missing:
        raise ValueError(f"preset missing fields: {sorted(missing)}")

    preset: dict[str, Any] = {}
    for field, value in raw.items():
        if field in INT_FIELDS:
            preset[field] = _to_int(value)
        elif field in ARRAY_FIELDS:
            preset[field] = [_to_int(entry) for entry in value]
        else:
            preset[field] = value

    if preset["reelWeightOffsets"][0] != 0:
        raise ValueError("reelWeightOffsets must start at zero")
    if len(preset["reelWeightOffsets"]) != preset["reelCount"] + 1:
        raise ValueError("reelWeightOffsets length must equal reelCount + 1")
    if preset["reelWeightOffsets"][-1] != len(preset["reelSymbolIds"]):
        raise ValueError("reelWeightOffsets end must match reelSymbolIds length")
    if len(preset["reelSymbolIds"]) != len(preset["reelSymbolWeights"]):
        raise ValueError("reelSymbolIds and reelSymbolWeights length mismatch")
    if len(preset["paytableSymbolIds"]) != len(preset["paytableMatchCounts"]):
        raise ValueError("paytable arrays length mismatch")
    if len(preset["paytableSymbolIds"]) != len(preset["paytableMultiplierBps"]):
        raise ValueError("paytable payout arrays length mismatch")
    if len(preset["jackpotTierIds"]) != len(preset["jackpotAwardMultiplierBps"]):
        raise ValueError("jackpot arrays length mismatch")
    if len(preset["jackpotTierIds"]) != len(preset["jackpotTierWeights"]):
        raise ValueError("jackpot weight arrays length mismatch")
    return preset


def load_presets(path: str | Path | None = None) -> dict[int, dict[str, Any]]:
    fixture_path = Path(path) if path is not None else DEFAULT_FIXTURE_PATH
    payload = json.loads(fixture_path.read_text())
    presets = payload["presets"]
    return {preset["presetId"]: preset for preset in (_normalize_preset(raw) for raw in presets)}


def load_preset(preset: int | str, path: str | Path | None = None) -> dict[str, Any]:
    presets = load_presets(path)
    if isinstance(preset, str) and preset.startswith("0x"):
        for loaded in presets.values():
            if loaded["configHash"].lower() == preset.lower():
                return loaded
        raise KeyError(f"unknown preset hash: {preset}")
    return presets[int(preset)]
