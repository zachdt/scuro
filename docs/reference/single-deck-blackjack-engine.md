# SingleDeckBlackjackEngine

## Purpose

`SingleDeckBlackjackEngine` tracks blackjack session state, validates coordinator proofs, exposes allowed player actions, and computes the solo settlement tuple.

## Caller Model

- Authorized controller opens sessions, declares actions, and claims player timeouts
- Coordinator submits initial-deal, action, and showdown proofs
- Clients read `getSession`, `requiredAdditionalBurn`, and `getSettlementOutcome`

## Roles And Permissions

- No local roles
- Controller authorization uses `GameCatalog.isAuthorizedControllerForEngine`
- Coordinator authorization is a single immutable address

## Constructor And Config

- `constructor(catalogAddress, verifierBundleAddress, coordinatorAddress, defaultActionWindow)`
- Constants exposed for action ids and action-mask flags

## Public API

- `catalog()`
- `engineType()`
- `openSession(player, wager, playRef, playerKeyCommitment)`
- `submitInitialDealProof(...)`
- `requiredAdditionalBurn(sessionId, action)`
- `declareAction(sessionId, player, action, additionalBurn)`
- `claimPlayerTimeout(sessionId)`
- `submitActionProof(...)`
- `submitShowdownProof(...)`
- `getSession(sessionId)`
- `getSettlementOutcome(sessionId)`

## Events

- `SessionOpened`
- `InitialDealResolved`
- `ActionDeclared`
- `ActionResolved`
- `PlayerTimeoutClaimed`
- `ShowdownResolved`

## State And Lifecycle Notes

- `SessionPhase` values are documented in [Enum and Phase Mappings](../concepts/protocol-enums.md)
- `requiredAdditionalBurn` is nonzero only for valid `doubleDown` or `split` states
- `submitActionProof` updates proof sequence, commitments, hand metadata, phase, and deadline together
- `submitShowdownProof` is the terminal engine step before controller settlement

## Revert Conditions

- Unauthorized controller or coordinator
- Module inactive
- Wrong phase for init, action, timeout, or showdown
- Expired player action window
- Disallowed action or bad additional burn
- Invalid verifier proof

## Test Anchors

- `test/BlackjackController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
