# Blackjack Playbook

## Purpose

This playbook covers the coordinator-assisted solo blackjack lifecycle.

The canonical blackjack ruleset lives in the [Blackjack session spec](../session-specs/blackjack.md). This page focuses on the controller/coordinator transaction flow.

## Transaction Sequence

1. Ensure the player has approved `ProtocolSettlement` for the wager and any expected follow-on burns.
2. Call `startHand(wager, playRef, playerKeyCommitment, expressionTokenId)`.
3. Coordinator submits `submitInitialDealProof(...)`.
4. Read `getSession(sessionId)` to determine the active hand, allowed actions, and `deadlineAt`.
5. Player calls `hit`, `stand`, `doubleDown`, or `split` through the controller.
6. Controller burns any additional wager required for `doubleDown` or `split`.
7. Coordinator submits `submitActionProof(...)` or `submitShowdownProof(...)`.
8. If the player misses the deadline, any caller may call `claimPlayerTimeout(sessionId)`.
9. Once `getSettlementOutcome(sessionId).completed` is true, any caller may call `settle(sessionId)`.

## Required Reads

- `sessionSettled(sessionId)` and `sessionExpressionTokenId(sessionId)` on the controller
- `requiredAdditionalBurn(sessionId, action)` and `getSession(sessionId)` on the engine

## Client Notes

- `pendingAction` plus `phase` determine whether the coordinator is expected to continue with an action proof or showdown proof.
- The engine exposes action-mask flags; clients should decode them with the mappings in [Enum and Phase Mappings](../concepts/protocol-enums.md).
- Developer accrual uses `totalBurned`, not just the opening wager.

## Relevant References

- [Blackjack Session Spec](../session-specs/blackjack.md)
- [BlackjackController](../reference/blackjack-controller.md)
- [Blackjack Engine](../reference/blackjack-engine.md)
- [Blackjack Verifier Bundle](../reference/blackjack-verifier-bundle.md)
