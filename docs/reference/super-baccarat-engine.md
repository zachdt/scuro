# SuperBaccaratEngine

## Purpose

`SuperBaccaratEngine` resolves one fresh baccarat round per request, computes the EV-neutral payout, and exposes the solo settlement tuple consumed by the controller.

For the canonical product rules and economics, see the [Super Baccarat session spec](../session-specs/super-baccarat.md).

## Caller Model

- Authorized controller calls `requestPlay`
- Configured VRF coordinator calls `rawFulfillRandomWords`
- Clients read round and settlement data directly

## Roles And Permissions

- No local roles
- Controller/engine authorization and lifecycle gating come from `GameCatalog`

## Constructor And Config

- `constructor(catalogAddress, vrfCoordinatorAddress)`
- Exposes `vrfCoordinator`, aggregate stats, and payout multipliers

## Public API

- `catalog()`
- `engineType()`
- `requestPlay(player, wager, side, playRef)`
- `rawFulfillRandomWords(requestId, randomWords)`
- `getRound(requestId)`
- `getSettlementOutcome(requestId)`
- `payoutMultiplierWad(side)`

## Events

- `PlayRequested`
- `PlayResolved`

## State And Lifecycle Notes

- Each request resolves a fresh eight-deck baccarat round through `BaccaratRules`
- Player and banker picks push on ties; tie picks win only when the outcome is tie
- The engine predicts the next request id by reading `requestCounter()` from the coordinator

## Revert Conditions

- Unauthorized controller
- Invalid wager or side
- Module inactive on fulfillment
- Wrong coordinator
- Unknown or already-fulfilled request
- Unexpected coordinator request id mismatch

## Test Anchors

- `test/SuperBaccaratController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
