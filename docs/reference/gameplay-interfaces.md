# Gameplay Interfaces

## Purpose

These interfaces define the stable gameplay surface that SDKs and alternate implementations should target before looking at concrete contracts.

## Interfaces Covered

- `IScuroGameEngine`
- `ISoloLifecycleEngine`
- `ITournamentGameEngine`
- `IPokerEngine`
- `IPokerZKEngine`

## Caller Model

- Controllers depend on these shapes to interact with engines
- SDKs can use them as language-agnostic traits or interface modules

## Public API

### `IScuroGameEngine`

- `engineType()`

### `ISoloLifecycleEngine`

- `getSettlementOutcome(sessionId)`

### `ITournamentGameEngine`

- `initializeGame(gameId, players, startingStacks, buyIn, reward)`
- `handleTimeout(gameId, player)`
- `isGameOver(gameId)`
- `getOutcomes(gameId)`

### `IPokerEngine`

- `submitInitialDealProof(...)`
- `declareDraw(gameId, cardIndices)`
- `getHandState(gameId)`
- `getCurrentPhase(gameId)`

### `IPokerZKEngine`

- `submitDrawProof(...)`
- `submitShowdownProof(...)`
- `claimTimeout(gameId)`
- `getProofDeadline(gameId)`

## State And Lifecycle Notes

- `ISoloLifecycleEngine.getSettlementOutcome` is the bridge between solo engines and settlement-capable controllers
- `IPokerEngine.HandStateView` is the canonical snapshot for poker hand indexing
- `IPokerZKEngine` extends `IPokerEngine` with coordinator-only proof transitions and timeout support

## Test Anchors

- `test/TournamentController.t.sol`
- `test/BlackjackController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
