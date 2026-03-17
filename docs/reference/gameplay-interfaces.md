# Gameplay Interfaces

## Purpose

These interfaces define the stable gameplay surface that SDKs and alternate implementations should target before looking at concrete contracts.

## Interfaces Covered

- `IScuroGameEngine`
- `ISoloLifecycleEngine`
- `ITournamentGameEngine`
- `ICheminDeFerEngine`
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

### `ICheminDeFerEngine`

- `requestResolution(tableId, playRef)`
- `isResolved(tableId)`
- `getRound(tableId)`

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
- `ICheminDeFerEngine` is the dedicated baccarat PvP surface for banker-opened, many-taker, one-shot tables
- `IPokerEngine.HandStateView` is the canonical snapshot for poker hand indexing
- `IPokerZKEngine` extends `IPokerEngine` with coordinator-only proof transitions and timeout support

## Test Anchors

- `test/TournamentController.t.sol`
- `test/BlackjackController.t.sol`
- `test/SuperBaccaratController.t.sol`
- `test/CheminDeFerController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
