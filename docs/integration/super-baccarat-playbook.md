# Super Baccarat Playbook

## Purpose

This playbook covers the minimum solo baccarat flow a Node or Rust API should support.

Product rules and economics live in the [Super Baccarat session spec](../session-specs/super-baccarat.md).

## Transaction Sequence

1. Ensure the player has approved `ProtocolSettlement` for the wager amount.
2. Optionally preflight `GameCatalog.isLaunchableController(superBaccaratController)`.
3. Call `SuperBaccaratController.play(wager, side, playRef, expressionTokenId)`.
4. Record the returned `sessionId`.
5. Watch `PlayRequested` and `PlayResolved`.
6. If local VRF is delayed rather than auto-callback, call `settle(sessionId)` once `getSettlementOutcome(sessionId).completed` is true.

## Read Sequence

- `sessionExpressionTokenId(sessionId)` and `sessionSettled(sessionId)` on the controller
- `getRound(sessionId)` on the engine
- `getSettlementOutcome(sessionId)` on the engine interface shape

## Client Notes

- The controller burns the wager before randomness is requested.
- The controller settles from the engine’s solo lifecycle tuple.
- Developer accrual uses the wager amount as activity.

## Relevant References

- [Super Baccarat Session Spec](../session-specs/super-baccarat.md)
- [SuperBaccaratController](../reference/super-baccarat-controller.md)
- [SuperBaccaratEngine](../reference/super-baccarat-engine.md)
