# BlackjackController

## Purpose

`BlackjackController` is the user-facing settlement wrapper around `SingleDeckBlackjackEngine`.

## Caller Model

- Players start hands and declare actions through the controller
- Any caller may claim timeout or settle once the engine is complete

## Roles And Permissions

- No local roles
- Launch and settlement gating are delegated to `GameCatalog`

## Constructor And Config

- `constructor(settlementAddress, catalogAddress, engineAddress)`

## Public API

- `engine()`
- `sessionSettled(sessionId)`
- `sessionExpressionTokenId(sessionId)`
- `startHand(wager, playRef, playerKeyCommitment, expressionTokenId)`
- `hit(sessionId)`
- `stand(sessionId)`
- `doubleDown(sessionId)`
- `split(sessionId)`
- `claimPlayerTimeout(sessionId)`
- `settle(sessionId)`

## Events

- `HandStarted`
- `SessionSettled`

## State And Lifecycle Notes

- Additional burn for `doubleDown` and `split` is computed by the engine before the controller burns funds
- Settlement uses the engine’s solo lifecycle tuple and accrues developer rewards from `totalBurned`

## Revert Conditions

- Module inactive
- Duplicate settlement
- Engine not yet completed
- Any bubbled engine action or timeout revert

## Test Anchors

- `test/BlackjackController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
