# NumberPickerEngine

## Purpose

`NumberPickerEngine` holds NumberPicker game state, statistics, and payout logic while leaving value movement to the controller and settlement layer.

For the canonical product rules and economics, see the [NumberPicker session spec](../session-specs/number-picker.md).

## Caller Model

- Authorized controller calls `requestPlay`
- Configured VRF coordinator calls `rawFulfillRandomWords`
- Clients read outcomes directly

## Roles And Permissions

- No local roles
- Controller/engine authorization and lifecycle gating come from `GameCatalog`

## Constructor And Config

- `constructor(catalogAddress, vrfCoordinatorAddress)`
- Exposes `vrfCoordinator`, aggregate stats, and `playRequests`

## Public API

- `catalog()`
- `engineType()`
- `requestPlay(player, wager, selection, playRef)`
- `rawFulfillRandomWords(requestId, randomWords)`
- `getOutcome(requestId)`
- `getSettlementOutcome(requestId)`

## Events

- `PlayRequested`
- `PlayResolved`

## State And Lifecycle Notes

- Valid selections are `1..99`
- Payout rule is `wager * 100 / selection` when `rollResult > selection`
- The engine predicts the next request id by reading `requestCounter()` from the coordinator

## Revert Conditions

- Unauthorized controller
- Invalid selection or wager
- Module inactive on fulfillment
- Wrong coordinator
- Unknown or already-fulfilled request
- Unexpected coordinator request id mismatch

## Test Anchors

- `test/NumberPickerAdapter.t.sol`
- `test/e2e/SmokeE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
