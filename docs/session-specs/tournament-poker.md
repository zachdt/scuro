# Tournament Poker Session Spec

## Product Identity And Session Owner

- Product: reusable tournament-config poker sessions
- Session owner: `TournamentController`
- Engine: `SingleDraw2To7Engine`
- Session model: an operator-defined tournament configuration that spawns independent two-player matches

## Session Creation Inputs And Actor Roles

- Operator creates tournament config with `entryFee`, `rewardPool`, `startingStack`, and `expressionTokenId`
- Operator starts concrete games for player pairs
- Players act directly on the poker engine during the hand loop
- Coordinator submits proof-bearing transitions
- Any caller may report the finished outcome through the controller

## Randomness / Proof Source

- Initial deal, draw resolution, and showdown are coordinator-submitted Groth16-backed proofs
- The controller does not own hidden-card logic; the poker engine and verifier bundle do

## Rules And Economic Parameters

- This is not a bracket manager
- `startingStack` is internal engine chip state only
- Settlement still pays the fixed controller-level `rewardPool`
- Both players burn `entryFee` up front
- Ties split the `rewardPool`
- Developer accrual uses `rewardPool + 2 * entryFee`

## Lifecycle / State Progression

1. Operator creates tournament config
2. Operator starts a game for two players
3. Controller burns both entry fees and initializes the shared poker engine
4. Engine loops hand-by-hand:
   - initial deal proof
   - pre-draw betting
   - draw declarations
   - draw proofs
   - post-draw betting
   - showdown proof
5. When one stack reaches zero, the engine reports completion
6. Any caller may call `reportOutcome(gameId)`

## Settlement Formulas And Precedence

- Engine-reported winner or tie outcome is authoritative
- Controller settlement mints from the fixed `rewardPool`, not final chip counts
- Ties split the `rewardPool`

## Timeouts, Forced Resolution, And Cancellation

- Player timeouts exist only in player-clock phases
- Coordinator-proof stalls are not auto-resolved by protocol timeouts
- Tournament configs may be toggled inactive by the operator, but existing games settle through the engine lifecycle

## Observability

Clients rely on:

- `tournaments(tournamentId)` and `gameToTournament(gameId)`
- `getHandState(gameId)`
- `getCurrentPhase(gameId)`
- `getProofDeadline(gameId)`
- `isGameOver(gameId)` and `getOutcomes(gameId)`
- tournament and poker engine lifecycle events

## Implementation Notes

- This spec matches the current implementation
- Tournament config storage is reusable, but each game is still a standalone heads-up poker match
