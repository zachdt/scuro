#!/usr/bin/env python3
"""Compute exact eight-deck punto banco outcome odds and neutral payout constants."""

from decimal import Decimal, getcontext
from functools import lru_cache

getcontext().prec = 60

INIT_COUNTS = (128,) + (32,) * 9


@lru_cache(maxsize=None)
def outcome_probs(counts, stage, player_total=0, banker_total=0, player_third=10):
    counts = list(counts)
    remaining = sum(counts)

    if stage == 0:
        return _branch(counts, remaining, lambda value: outcome_probs(tuple(counts), 1, value % 10, banker_total, player_third))
    if stage == 1:
        return _branch(counts, remaining, lambda value: outcome_probs(tuple(counts), 2, player_total, value % 10, player_third))
    if stage == 2:
        return _branch(counts, remaining, lambda value: outcome_probs(tuple(counts), 3, (player_total + value) % 10, banker_total, player_third))
    if stage == 3:
        out = [Decimal(0), Decimal(0), Decimal(0)]
        for value, count in enumerate(counts):
            if count == 0:
                continue
            counts[value] -= 1
            next_banker_total = (banker_total + value) % 10
            if player_total in (8, 9) or next_banker_total in (8, 9):
                sub = compare(player_total, next_banker_total)
            elif player_total <= 5:
                sub = outcome_probs(tuple(counts), 4, player_total, next_banker_total, 10)
            elif next_banker_total <= 5:
                sub = outcome_probs(tuple(counts), 5, player_total, next_banker_total, 11)
            else:
                sub = compare(player_total, next_banker_total)
            counts[value] += 1
            probability = Decimal(count) / Decimal(remaining)
            for index in range(3):
                out[index] += probability * sub[index]
        return tuple(out)
    if stage == 4:
        out = [Decimal(0), Decimal(0), Decimal(0)]
        for value, count in enumerate(counts):
            if count == 0:
                continue
            counts[value] -= 1
            sub = outcome_probs(tuple(counts), 5, (player_total + value) % 10, banker_total, value)
            counts[value] += 1
            probability = Decimal(count) / Decimal(remaining)
            for index in range(3):
                out[index] += probability * sub[index]
        return tuple(out)
    if stage == 5:
        if should_banker_draw(banker_total, player_third):
            out = [Decimal(0), Decimal(0), Decimal(0)]
            for value, count in enumerate(counts):
                if count == 0:
                    continue
                probability = Decimal(count) / Decimal(remaining)
                sub = compare(player_total, (banker_total + value) % 10)
                for index in range(3):
                    out[index] += probability * sub[index]
            return tuple(out)
        return compare(player_total, banker_total)
    raise ValueError(stage)


def _branch(counts, remaining, next_stage):
    out = [Decimal(0), Decimal(0), Decimal(0)]
    for value, count in enumerate(counts):
        if count == 0:
            continue
        counts[value] -= 1
        sub = next_stage(value)
        counts[value] += 1
        probability = Decimal(count) / Decimal(remaining)
        for index in range(3):
            out[index] += probability * sub[index]
    return tuple(out)


def should_banker_draw(banker_total, player_third):
    if player_third == 11:
        return banker_total <= 5
    if banker_total <= 2:
        return True
    if banker_total == 3:
        return player_third != 8
    if banker_total == 4:
        return 2 <= player_third <= 7
    if banker_total == 5:
        return 4 <= player_third <= 7
    if banker_total == 6:
        return player_third in (6, 7)
    return False


def compare(player_total, banker_total):
    if player_total > banker_total:
        return (Decimal(1), Decimal(0), Decimal(0))
    if banker_total > player_total:
        return (Decimal(0), Decimal(1), Decimal(0))
    return (Decimal(0), Decimal(0), Decimal(1))


def wad(value):
    return int(value * Decimal(10) ** 18)


if __name__ == "__main__":
    player_prob, banker_prob, tie_prob = outcome_probs(INIT_COUNTS, 0)
    player_multiplier = (Decimal(1) - tie_prob) / player_prob
    banker_multiplier = (Decimal(1) - tie_prob) / banker_prob
    tie_multiplier = Decimal(1) / tie_prob
    banker_risk_ratio = banker_prob / player_prob

    print(f"player_prob={player_prob}")
    print(f"banker_prob={banker_prob}")
    print(f"tie_prob={tie_prob}")
    print(f"PLAYER_PAYOUT_WAD={wad(player_multiplier)}")
    print(f"BANKER_PAYOUT_WAD={wad(banker_multiplier)}")
    print(f"TIE_PAYOUT_WAD={wad(tie_multiplier)}")
    print(f"BANKER_RISK_PER_PLAYER_WAD={wad(banker_risk_ratio)}")
