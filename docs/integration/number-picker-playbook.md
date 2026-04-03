# NumberPicker Playbook

## Purpose

This playbook is the minimum solo-game flow a Node or Rust API should support.

Product rules and economics live in the [NumberPicker session spec](../session-specs/number-picker.md).

## Transaction Sequence

1. Ensure the player has approved `ProtocolSettlement` for the wager amount.
2. Optionally preflight `GameCatalog.isLaunchableController(numberPickerAdapter)`.
3. Call `NumberPickerAdapter.play(wager, selection, playRef, expressionTokenId)`.
4. Record the returned `requestId`.
5. Watch `PlayRequested` and `PlayResolved`.
6. If local VRF is delayed rather than auto-callback, call `finalize(requestId)` once `getSettlementOutcome(requestId).completed` is true.

## Read Sequence

- `requestExpressionTokenId(requestId)` and `requestSettled(requestId)` on the adapter
- `getOutcome(requestId)` on the engine
- `getSettlementOutcome(requestId)` on the engine interface shape

## Client Notes

- The controller burns the wager before randomness is requested.
- The payout basis is engine-defined and must match `getOutcome`.
- Developer accrual uses the wager amount as activity.

## Relevant References

- [NumberPicker Session Spec](../session-specs/number-picker.md)
- [NumberPickerAdapter](../reference/number-picker-adapter.md)
- [NumberPickerEngine](../reference/number-picker-engine.md)
