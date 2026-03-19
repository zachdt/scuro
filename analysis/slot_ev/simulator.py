from __future__ import annotations

import math
import statistics
import time
from dataclasses import dataclass
from hashlib import sha3_256
from typing import Any

try:
    import numpy as np
except ImportError:  # pragma: no cover - optional dependency
    np = None

try:
    import polars as pl
except ImportError:  # pragma: no cover - optional dependency
    pl = None

try:
    from eth_hash.auto import keccak
except ImportError:  # pragma: no cover - fallback for syntax-only environments
    keccak = None


@dataclass(frozen=True)
class SpinOutcome:
    payout: int
    hit: bool
    triggered_free_spins: bool
    triggered_pick_bonus: bool
    triggered_hold_and_spin: bool
    free_spin_payout: int
    pick_bonus_payout: int
    hold_and_spin_payout: int
    jackpot_tier_hit: int
    jackpot_payout: int
    total_event_count: int


def _keccak_uint(*parts: Any) -> int:
    if keccak is not None:
        payload = "|".join(str(part) for part in parts).encode("utf-8")
        return int.from_bytes(keccak(payload), "big")
    payload = "|".join(str(part) for part in parts).encode("utf-8")
    return int.from_bytes(sha3_256(payload).digest(), "big")


def _draw_weighted_symbol(preset: dict[str, Any], seed: int, salt: int, reel: int, row: int) -> int:
    start = preset["reelWeightOffsets"][reel]
    end = preset["reelWeightOffsets"][reel + 1]
    weights = preset["reelSymbolWeights"][start:end]
    total_weight = sum(weights)
    draw = _keccak_uint(seed, salt, reel, row) % total_weight

    running = 0
    for symbol_id, weight in zip(preset["reelSymbolIds"][start:end], weights):
        running += weight
        if draw < running:
            return symbol_id
    return preset["reelSymbolIds"][end - 1]


def _generate_grid(preset: dict[str, Any], seed: int, salt: int) -> list[int]:
    grid: list[int] = []
    for reel in range(preset["reelCount"]):
        for row in range(preset["rowCount"]):
            grid.append(_draw_weighted_symbol(preset, seed, salt, reel, row))
    return grid


def _count_symbol(grid: list[int], symbol_id: int) -> int:
    return sum(1 for symbol in grid if symbol == symbol_id)


def _count_ways(preset: dict[str, Any], grid: list[int], symbol_id: int) -> tuple[int, int]:
    matches = 0
    ways_count = 1
    for reel in range(preset["reelCount"]):
        reel_matches = 0
        for row in range(preset["rowCount"]):
            current = grid[(reel * preset["rowCount"]) + row]
            if current == symbol_id or (preset["wildSymbolId"] != 0 and current == preset["wildSymbolId"]):
                reel_matches += 1
        if reel_matches == 0:
            break
        matches += 1
        ways_count *= reel_matches
    if matches == 0:
        ways_count = 0
    return matches, ways_count


def _evaluate_ways(preset: dict[str, Any], stake: int, grid: list[int]) -> int:
    payout = 0
    for symbol_id, match_count, multiplier_bps in zip(
        preset["paytableSymbolIds"], preset["paytableMatchCounts"], preset["paytableMultiplierBps"]
    ):
        matches, ways_count = _count_ways(preset, grid, symbol_id)
        if matches >= match_count and ways_count > 0:
            payout += (stake * multiplier_bps * ways_count) // 10_000
    return payout


def _lookup_free_spin_count(preset: dict[str, Any], symbol_count: int) -> int:
    if symbol_count <= preset["freeSpinTriggerCount"]:
        return preset["freeSpinAwardCounts"][0]
    index = min(symbol_count - preset["freeSpinTriggerCount"], len(preset["freeSpinAwardCounts"]) - 1)
    return preset["freeSpinAwardCounts"][index]


def _resolve_free_spins(preset: dict[str, Any], stake: int, seed: int, starting_events: int) -> tuple[int, int, int, int]:
    awarded_spins = _lookup_free_spin_count(preset, preset["freeSpinTriggerCount"])
    spins_remaining = awarded_spins
    spin_index = 0
    payout = 0
    retriggers_used = 0
    event_count = 0

    while spins_remaining > 0:
        if starting_events + event_count >= preset["maxTotalEvents"]:
            raise ValueError("event cap exceeded in free spins")
        grid = _generate_grid(preset, seed, 10_000 + spin_index)
        payout += (_evaluate_ways(preset, stake, grid) * preset["freeSpinMultiplierBps"]) // 10_000
        event_count += 1

        scatter_count = _count_symbol(grid, preset["scatterSymbolId"])
        if (
            scatter_count >= preset["freeSpinTriggerCount"]
            and retriggers_used < preset["maxRetriggers"]
            and awarded_spins < preset["maxFreeSpins"]
        ):
            extra = _lookup_free_spin_count(preset, scatter_count)
            if awarded_spins + extra > preset["maxFreeSpins"]:
                extra = preset["maxFreeSpins"] - awarded_spins
            awarded_spins += extra
            spins_remaining += extra
            retriggers_used += 1

        spins_remaining -= 1
        spin_index += 1

    return awarded_spins, payout, retriggers_used, event_count


def _resolve_pick_bonus(preset: dict[str, Any], stake: int, seed: int, starting_events: int) -> tuple[int, int]:
    reveals = preset["maxPickReveals"]
    if starting_events + reveals > preset["maxTotalEvents"]:
        raise ValueError("event cap exceeded in pick bonus")

    payout = 0
    for reveal in range(reveals):
        award_index = _keccak_uint(seed, 20_000 + reveal) % len(preset["pickAwardMultiplierBps"])
        payout += (stake * preset["pickAwardMultiplierBps"][award_index]) // 10_000
    return payout, reveals


def _draw_jackpot(preset: dict[str, Any], stake: int, seed: int, salt: int) -> tuple[int, int]:
    if not preset["jackpotTierIds"]:
        return 0, 0
    total_weight = sum(preset["jackpotTierWeights"])
    draw = _keccak_uint(seed, salt, "jackpot") % total_weight
    running = 0
    for tier_id, weight, payout_bps in zip(
        preset["jackpotTierIds"], preset["jackpotTierWeights"], preset["jackpotAwardMultiplierBps"]
    ):
        running += weight
        if draw < running:
            return tier_id, (stake * payout_bps) // 10_000
    last_index = len(preset["jackpotTierIds"]) - 1
    return preset["jackpotTierIds"][last_index], (stake * preset["jackpotAwardMultiplierBps"][last_index]) // 10_000


def _resolve_hold_and_spin(
    preset: dict[str, Any], stake: int, seed: int, starting_events: int, initial_filled: int
) -> tuple[int, int, int, int, int, int]:
    spins_remaining = preset["initialRespins"]
    respins_used = 0
    filled = min(initial_filled, preset["holdBoardSize"])
    payout = 0
    jackpot_tier_hit = 0
    jackpot_payout = 0
    event_count = 0

    while spins_remaining > 0 and filled < preset["holdBoardSize"]:
        if starting_events + event_count >= preset["maxTotalEvents"]:
            raise ValueError("event cap exceeded in hold and spin")

        remaining_slots = preset["holdBoardSize"] - filled
        new_hits = _keccak_uint(seed, 30_000 + respins_used) % (remaining_slots + 1)
        if new_hits > 0:
            spins_remaining = preset["initialRespins"]
        else:
            spins_remaining -= 1

        new_hits = min(new_hits, remaining_slots)
        for hit_index in range(new_hits):
            value_index = _keccak_uint(seed, 31_000 + respins_used, hit_index) % len(preset["holdValueMultiplierBps"])
            payout += (stake * preset["holdValueMultiplierBps"][value_index]) // 10_000

        filled += new_hits
        respins_used += 1
        event_count += 1
        if respins_used >= preset["maxRespins"]:
            break

    if filled == preset["holdBoardSize"]:
        jackpot_tier_hit, jackpot_payout = _draw_jackpot(preset, stake, seed, 40_000 + respins_used)
        payout += jackpot_payout

    return payout, filled, respins_used, jackpot_tier_hit, jackpot_payout, event_count


def simulate_spin(preset: dict[str, Any], seed: int, stake: int = 10**18) -> SpinOutcome:
    grid = _generate_grid(preset, seed, 0)
    payout = _evaluate_ways(preset, stake, grid)
    event_count = 0

    scatter_count = _count_symbol(grid, preset["scatterSymbolId"])
    bonus_count = _count_symbol(grid, preset["bonusSymbolId"])
    jackpot_count = _count_symbol(grid, preset["jackpotSymbolId"])

    triggered_free_spins = preset["freeSpinTriggerCount"] > 0 and scatter_count >= preset["freeSpinTriggerCount"]
    triggered_pick_bonus = preset["pickTriggerCount"] > 0 and bonus_count >= preset["pickTriggerCount"]
    triggered_hold_and_spin = preset["holdTriggerCount"] > 0 and (bonus_count + jackpot_count) >= preset["holdTriggerCount"]

    free_spin_payout = 0
    pick_bonus_payout = 0
    hold_and_spin_payout = 0
    jackpot_tier_hit = 0
    jackpot_payout = 0

    if triggered_free_spins:
        _, free_spin_payout, _, free_events = _resolve_free_spins(preset, stake, seed, event_count)
        payout += free_spin_payout
        event_count += free_events

    if triggered_pick_bonus:
        pick_bonus_payout, pick_events = _resolve_pick_bonus(preset, stake, seed, event_count)
        payout += pick_bonus_payout
        event_count += pick_events

    if triggered_hold_and_spin:
        hold_and_spin_payout, _, _, jackpot_tier_hit, jackpot_payout, hold_events = _resolve_hold_and_spin(
            preset, stake, seed, event_count, bonus_count + jackpot_count
        )
        payout += hold_and_spin_payout
        event_count += hold_events

    max_payout = (stake * preset["maxPayoutMultiplierBps"]) // 10_000
    if payout > max_payout:
        raise ValueError("payout cap exceeded")
    if event_count > preset["maxTotalEvents"]:
        raise ValueError("event cap exceeded")

    return SpinOutcome(
        payout=payout,
        hit=payout > 0,
        triggered_free_spins=triggered_free_spins,
        triggered_pick_bonus=triggered_pick_bonus,
        triggered_hold_and_spin=triggered_hold_and_spin,
        free_spin_payout=free_spin_payout,
        pick_bonus_payout=pick_bonus_payout,
        hold_and_spin_payout=hold_and_spin_payout,
        jackpot_tier_hit=jackpot_tier_hit,
        jackpot_payout=jackpot_payout,
        total_event_count=event_count,
    )


def simulate_many(
    preset: dict[str, Any], sample_size: int, base_seed: int = 1, stake: int = 10**18, target_ev_ratio: float = 1.0
) -> dict[str, Any]:
    start = time.perf_counter()
    if np is not None:
        rng = np.random.default_rng(base_seed)
        seeds = [int(value) for value in rng.integers(1, 2**63 - 1, size=sample_size, dtype=np.int64)]
    else:
        seeds = [base_seed + index + 1 for index in range(sample_size)]

    outcomes = [simulate_spin(preset, seed, stake=stake) for seed in seeds]
    elapsed = max(time.perf_counter() - start, 1e-9)
    payout_ratios = [outcome.payout / stake for outcome in outcomes]

    if pl is not None:
        frame = pl.DataFrame(
            {
                "payout_ratio": payout_ratios,
                "hit": [outcome.hit for outcome in outcomes],
                "free_spins": [outcome.triggered_free_spins for outcome in outcomes],
                "pick_bonus": [outcome.triggered_pick_bonus for outcome in outcomes],
                "hold_and_spin": [outcome.triggered_hold_and_spin for outcome in outcomes],
                "jackpot_tier_hit": [outcome.jackpot_tier_hit for outcome in outcomes],
            }
        )
        ev_ratio = float(frame["payout_ratio"].mean())
        variance = float(frame["payout_ratio"].var(ddof=0))
        hit_rate = float(frame["hit"].mean())
        free_spin_rate = float(frame["free_spins"].mean())
        pick_bonus_rate = float(frame["pick_bonus"].mean())
        hold_and_spin_rate = float(frame["hold_and_spin"].mean())
    else:
        ev_ratio = statistics.fmean(payout_ratios)
        variance = statistics.pvariance(payout_ratios)
        hit_rate = sum(1 for outcome in outcomes if outcome.hit) / sample_size
        free_spin_rate = sum(1 for outcome in outcomes if outcome.triggered_free_spins) / sample_size
        pick_bonus_rate = sum(1 for outcome in outcomes if outcome.triggered_pick_bonus) / sample_size
        hold_and_spin_rate = sum(1 for outcome in outcomes if outcome.triggered_hold_and_spin) / sample_size

    stddev = math.sqrt(variance)
    margin = 1.96 * stddev / math.sqrt(sample_size)
    jackpot_frequency: dict[int, float] = {}
    for tier_id in preset["jackpotTierIds"]:
        jackpot_hits = sum(1 for outcome in outcomes if outcome.jackpot_tier_hit == tier_id)
        jackpot_frequency[tier_id] = jackpot_hits / sample_size

    return {
        "preset_id": preset["presetId"],
        "config_hash": preset["configHash"],
        "volatility_tier": preset["volatilityTier"],
        "sample_size": sample_size,
        "stake": stake,
        "target_ev_ratio": target_ev_ratio,
        "ev_ratio": ev_ratio,
        "ev_deviation": ev_ratio - target_ev_ratio,
        "variance": variance,
        "stddev": stddev,
        "hit_rate": hit_rate,
        "bonus_trigger_frequency": {
            "free_spins": free_spin_rate,
            "pick_bonus": pick_bonus_rate,
            "hold_and_spin": hold_and_spin_rate,
        },
        "jackpot_frequency": jackpot_frequency,
        "max_observed_payout": max(outcome.payout for outcome in outcomes),
        "max_observed_event_count": max(outcome.total_event_count for outcome in outcomes),
        "confidence_interval_95": [ev_ratio - margin, ev_ratio + margin],
        "performance": {
            "wall_seconds": elapsed,
            "spins_per_second": sample_size / elapsed,
        },
    }
