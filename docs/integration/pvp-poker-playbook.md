# PvP Poker Playbook

## Purpose

This playbook covers the one-off heads-up poker flow.

Product rules and economics live in the [PvP Poker session spec](../session-specs/pvp-poker.md).

## Transaction Sequence

1. Operator calls `createSession(p1, p2, stake, rewardPool, startingStack, expressionTokenId)`.
2. Players and coordinator drive the shared poker engine lifecycle exactly as in tournament poker.
3. Any caller calls `settleSession(sessionId)` once `isGameOver(sessionId)` is true.

## Required Reads

- `sessions(sessionId)` and `sessionSettled(sessionId)` on the controller
- `getHandState(sessionId)`, `getCurrentPhase(sessionId)`, `getProofDeadline(sessionId)`, `isGameOver(sessionId)`, and `getOutcomes(sessionId)` on the engine

## Client Notes

- Stakes are burned up front through settlement.
- Settlement later distributes the fixed `rewardPool`.
- Developer accrual uses `rewardPool + 2 * stake`.

## Relevant References

- [PvP Poker Session Spec](../session-specs/pvp-poker.md)
- [PvPController](../reference/pvp-controller.md)
- [SingleDraw2To7Engine](../reference/single-draw-2-7-engine.md)
