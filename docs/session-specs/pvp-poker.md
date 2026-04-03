# PvP Poker Session Spec

## Product Identity And Session Owner

- Product: one-off heads-up PvP poker
- Session owner: `PvPController`
- Engine: `SingleDraw2To7Engine`
- Session model: one controller-created heads-up match settled from a fixed reward pool

## Session Creation Inputs And Actor Roles

- Operator creates the session with `player1`, `player2`, `stake`, `rewardPool`, `startingStack`, and `expressionTokenId`
- Players act directly on the poker engine during active hand phases
- Coordinator submits proof-bearing deal, draw, and showdown transitions
- Any caller may settle a completed session

## Randomness / Proof Source

- Hidden-card transitions are coordinator-submitted Groth16-backed proofs through the shared poker engine

## Rules And Economic Parameters

- Stakes are burned up front through the controller
- `stake` may be zero
- `startingStack` is internal engine chip state only
- Settlement later pays the fixed `rewardPool`
- Developer accrual uses `rewardPool + 2 * stake`

## Lifecycle / State Progression

1. Operator creates the session
2. Controller burns both stakes and initializes the poker engine
3. Engine runs the same hand loop used by tournament poker until one stack reaches zero
4. Any caller calls `settleSession(sessionId)` once the engine reports completion

## Settlement Formulas And Precedence

- Engine-reported winner or tie outcome is authoritative
- Controller settlement uses the fixed `rewardPool`
- Tie outcomes split the `rewardPool`

## Timeouts, Forced Resolution, And Cancellation

- Player timeouts only apply to player-clock phases on the engine
- Coordinator-proof stalls remain an operational concern
- No controller-side cancellation path exists after session creation

## Observability

Clients rely on:

- `sessions(sessionId)`
- `sessionSettled(sessionId)`
- `getHandState(sessionId)`
- `getCurrentPhase(sessionId)`
- `getProofDeadline(sessionId)`
- `isGameOver(sessionId)` and `getOutcomes(sessionId)`

## Implementation Notes

- This spec matches the current implementation
- The main distinction from tournament poker is that there is no reusable tournament configuration layer
