# Tournament Poker Playbook

## Purpose

This playbook covers the reusable tournament configuration plus per-game settlement flow.

## Transaction Sequence

1. Operator calls `createTournament(entryFee, rewardPool, startingStack, expressionTokenId)`.
2. Operator calls `startGameForPlayers(tournamentId, p1, p2)`.
3. Coordinator submits `submitInitialDealProof(...)` to the poker engine.
4. Players drive betting and draw declaration directly on the engine.
5. Coordinator submits `submitDrawProof(...)` for each player.
6. Players complete post-draw betting.
7. Coordinator submits `submitShowdownProof(winnerAddr, isTie, proof)`.
8. Any caller calls `reportOutcome(gameId)` once the engine reports completion.

## Required Reads

- `tournaments(tournamentId)` and `gameToTournament(gameId)` on the controller
- `getHandState(gameId)`, `getCurrentPhase(gameId)`, `getProofDeadline(gameId)`, `isGameOver(gameId)`, and `getOutcomes(gameId)` on the engine

## Client Notes

- The controller is not a bracket manager. It stores reusable buy-in and reward settings only.
- `startingStack` is engine-local tournament chip state. Controller settlement still uses the fixed `rewardPool`.
- Timeouts only exist for player-clock phases; stalled coordinator proof submission must be handled operationally.

## Relevant References

- [TournamentController](../reference/tournament-controller.md)
- [SingleDraw2To7Engine](../reference/single-draw-2-7-engine.md)
- [Poker Verifier Bundle](../reference/poker-verifier-bundle.md)
