# SingleDraw2To7Engine

## Purpose

`SingleDraw2To7Engine` is the shared poker engine for both tournament and PvP controllers. It manages heads-up hand state, blind posting, draw resolution, showdown verification, and final payout routing.

For the canonical product rules and economics of the controller-owned session types, see the [Tournament Poker session spec](../session-specs/tournament-poker.md) and [PvP Poker session spec](../session-specs/pvp-poker.md).

## Caller Model

- Authorized controllers initialize games and may call `handleTimeout`
- Players call `bet`, `fold`, and `declareDraw`
- Coordinator or controller submits proofs through the coordinator-gated functions
- Clients read hand state, phase, deadlines, and outcomes directly

## Roles And Permissions

- No local roles
- Controller binding is enforced through `GameCatalog`
- `onlyCoordinator(gameId)` accepts either the immutable hand coordinator or the registered controller

## Constructor And Config

- `constructor(catalogAddress, smallBlind, bigBlind, blindInterval, actionWindow, verifierBundle, handCoordinator)`
- Exposes the default blinds, escalation interval, action window, verifier bundle, and hand coordinator

## Public API

- `catalog()`
- `engineType()`
- `initializeGame(gameId, players, startingStacks, buyIn, reward)`
- `bet(gameId, amount)`
- `fold(gameId)`
- `submitInitialDealProof(...)`
- `declareDraw(gameId, cardIndices)`
- `submitDrawProof(...)`
- `submitShowdownProof(gameId, winnerAddr, isTie, proof)`
- `claimTimeout(gameId)`
- `handleTimeout(gameId, player)`
- `isGameOver(gameId)`
- `getOutcomes(gameId)`
- `getHandState(gameId)`
- `getCurrentPhase(gameId)`
- `getProofDeadline(gameId)`

## Events

- `HandAwaitingInitialDeal`
- `PublicActionTaken`
- `DrawDeclared`
- `DrawResolved`
- `ShowdownSubmitted`

## State And Lifecycle Notes

- Hands loop until one player stack reaches zero
- Blind sizes escalate as powers of two based on elapsed intervals
- `claimTimeout` and `handleTimeout` resolve only player-clock phases, never coordinator-proof stalls
- Ties split the controller-level reward pool on settlement

## Revert Conditions

- Unauthorized controller or coordinator
- Module inactive
- Wrong player turn
- Expired action deadline
- Invalid betting, draw declaration, or proof payload
- Reads like `getOutcomes` revert until the match is complete

## Test Anchors

- `test/TournamentController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
