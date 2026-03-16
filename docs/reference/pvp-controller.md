# PvPController

## Purpose

`PvPController` launches and settles one-off heads-up poker sessions without the reusable tournament config layer.

## Caller Model

- Operators create sessions
- Any caller may settle a completed session

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `OPERATOR_ROLE`

## Constructor And Config

- `constructor(admin, settlementAddress, catalogAddress, engineAddress)`
- `nextSessionId` starts at `1`

## Public API

- `settlement()`
- `catalog()`
- `engine()`
- `createSession(player1, player2, stake, rewardPool, startingStack, expressionTokenId)`
- `settleSession(sessionId)`

## Events

- `SessionCreated`
- `SessionSettled`

## State And Lifecycle Notes

- Stakes are optional; a zero-stake session is allowed
- The controller stores `expressionTokenId` per session for later settlement
- Developer accrual uses `rewardPool + 2 * stake`

## Revert Conditions

- Missing `OPERATOR_ROLE`
- Module inactive
- Session inactive or already settled
- Engine still active

## Test Anchors

- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/SmokeE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
