# CheminDeFerEngine

## Purpose

`CheminDeFerEngine` requests VRF for a banker-opened table, stores one baccarat round outcome, and exposes the resolved round for controller settlement.

For the canonical product rules and economics, see the [Chemin de Fer session spec](../session-specs/chemin-de-fer.md).

## Caller Model

- Authorized controller calls `requestResolution`
- Configured VRF coordinator calls `rawFulfillRandomWords`
- Clients read round data and resolution status directly

## Roles And Permissions

- No local roles
- Controller/engine authorization and lifecycle gating come from `GameCatalog`

## Constructor And Config

- `constructor(catalogAddress, vrfCoordinatorAddress)`
- Exposes `vrfCoordinator` and `requestToTableId`

## Public API

- `catalog()`
- `engineType()`
- `requestResolution(tableId, playRef)`
- `rawFulfillRandomWords(requestId, randomWords)`
- `isResolved(tableId)`
- `getRound(tableId)`

## Events

- `ResolutionRequested`
- `ResolutionCompleted`

## State And Lifecycle Notes

- Each table resolves exactly one baccarat round through `BaccaratRules`
- The engine predicts the next request id by reading `requestCounter()` from the coordinator
- Settlement routing stays in the controller; the engine only stores the round result

## Revert Conditions

- Unauthorized controller
- Duplicate resolution request for the same table
- Module inactive on fulfillment
- Wrong coordinator
- Unknown request id or already-resolved table
- Unexpected coordinator request id mismatch

## Test Anchors

- `test/CheminDeFerController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
