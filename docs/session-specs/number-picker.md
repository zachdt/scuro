# NumberPicker Session Spec

## Product Identity And Session Owner

- Product: NumberPicker
- Session owner: `NumberPickerAdapter`
- Session model: one wagered solo request resolved from one VRF callback

## Session Creation Inputs And Actor Roles

- Player supplies `wager`, `selection`, `playRef`, and `expressionTokenId`
- Controller burns the wager before requesting randomness
- VRF coordinator resolves the request
- Any caller may finalize if the outcome is resolved but not yet settled by the controller

## Randomness / Proof Source

- Source: VRF-backed single random word
- Local test flows may auto-callback immediately, making the session effectively single-transaction

## Rules And Economic Parameters

- Valid selections are `1..99`
- The engine computes `rollResult = (randomWord % 100) + 1`
- Win condition: `rollResult > selection`
- Gross payout on win: `wager * 100 / selection`
- Loss payout: `0`

The product edge is fully determined by the selection-based payout formula and integer rounding behavior in the engine.

## Lifecycle / State Progression

1. Player calls `play(...)`
2. Controller burns the wager
3. Engine requests VRF
4. VRF fulfills the request
5. Engine stores result and settlement tuple
6. Controller finalizes immediately if the request is already resolved, otherwise any caller may later call `finalize(requestId)`

## Settlement Formulas And Precedence

- The engine settlement tuple is authoritative for controller minting
- Controller finalization checks that `getOutcome(requestId).payout` matches `getSettlementOutcome(requestId).payout`
- Developer accrual uses the burned wager, not the payout

## Timeouts, Forced Resolution, And Cancellation

- No player action clock after request creation
- No cancellation after randomness is requested
- Delayed VRF is handled by waiting for fulfillment, not by timeout resolution

## Observability

Clients rely on:

- `requestSettled(requestId)`
- `requestExpressionTokenId(requestId)`
- `getOutcome(requestId)`
- `getSettlementOutcome(requestId)`
- `PlayRequested` and `PlayResolved` engine events plus `PlayFinalized`

## Implementation Notes

- This spec matches the current implementation
- The core client distinction is immediate finalization vs delayed finalization depending on VRF behavior
