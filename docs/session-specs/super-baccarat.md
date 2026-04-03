# Super Baccarat Session Spec

## Product Identity And Session Owner

- Product: Super Baccarat
- Session owner: `SuperBaccaratController`
- Session model: one solo punto banco side pick resolved from one fresh baccarat round

## Session Creation Inputs And Actor Roles

- Player supplies `wager`, `side`, `playRef`, and `expressionTokenId`
- Controller burns the wager before requesting the round
- Engine resolves the round from VRF
- Any caller may settle a completed round

## Randomness / Proof Source

- Source: VRF-backed single random word
- Each session deals a fresh eight-deck baccarat round
- The draw tableau is fully automated by `BaccaratRules`

## Rules And Economic Parameters

- Available sides:
  - Player
  - Banker
  - Tie
- The engine treats ties as pushes for Player and Banker picks
- Gross payout multipliers are hardcoded:
  - Player: `2_027_677_102_818_402_306 / 1e18`
  - Banker: `1_973_068_288_918_281_910 / 1e18`
  - Tie: `10_509_062_340_173_595_362 / 1e18`
  - Push: `1e18 / 1e18`

These constants are chosen so the solo baccarat picks are EV-neutral over the exact modeled eight-deck odds.

## Lifecycle / State Progression

1. Player calls `play(...)`
2. Controller burns the wager
3. Engine requests VRF
4. VRF fulfills the request
5. Engine resolves the baccarat tableau and payout
6. Any caller may settle once the session is complete

## Settlement Formulas And Precedence

- Tie selected and tie occurs: pay tie multiplier
- Player or Banker selected and tie occurs: push the opening wager
- Correct non-tie side selected: pay the side multiplier
- Incorrect side selected: pay `0`
- Developer accrual uses the burned wager

## Timeouts, Forced Resolution, And Cancellation

- No player action phases after play request
- No cancellation after randomness request
- Delayed VRF environments simply delay later settlement

## Observability

Clients rely on:

- `sessionSettled(sessionId)`
- `sessionExpressionTokenId(sessionId)`
- `getRound(sessionId)`
- `getSettlementOutcome(sessionId)`
- `PlayStarted`, `PlayRequested`, `PlayResolved`, and `SessionSettled`

## Implementation Notes

- This spec matches the current implementation
- The gameplay edge is entirely encoded in the payout multipliers and the automated baccarat tableau
