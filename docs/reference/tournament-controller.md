# TournamentController

## Purpose

`TournamentController` stores reusable tournament configs and starts concrete two-player poker games against the shared engine.

## Caller Model

- Operators create tournaments and start games
- Any caller may report outcomes after engine completion

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `OPERATOR_ROLE`

## Constructor And Config

- `constructor(admin, settlementAddress, catalogAddress, engineAddress)`
- `nextTournamentId` and `nextGameId` both start at `1`

## Public API

- `settlement()`
- `catalog()`
- `engine()`
- `createTournament(entryFee, rewardPool, startingStack, expressionTokenId)`
- `setTournamentActive(tournamentId, active)`
- `startGameForPlayers(tournamentId, p1, p2)`
- `reportOutcome(gameId)`

## Events

- `TournamentCreated`
- `TournamentActiveSet`
- `GameStarted`
- `GameSettled`

## State And Lifecycle Notes

- The controller does not manage brackets, winners, or advancement beyond one game
- `entryFee` burns happen before `initializeGame`
- Settlement mints engine-reported payouts and then accrues developer rewards from `rewardPool + 2 * entryFee`

## Revert Conditions

- Missing `OPERATOR_ROLE`
- Module inactive
- Inactive tournament
- Double outcome reporting
- Engine still active

## Test Anchors

- `test/TournamentController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
