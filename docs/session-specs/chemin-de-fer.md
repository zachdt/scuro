# Chemin de Fer Session Spec

## Product Identity And Session Owner

- Product: automated chemin de fer baccarat table
- Session owner: `CheminDeFerController`
- Session model: banker-opened table with permissionless takers, one baccarat resolution, and proportional settlement

## Session Creation Inputs And Actor Roles

- Banker opens table with `bankerMaxBet`, `playRef`, and `expressionTokenId`
- Takers join the table by contributing `take` amounts before the join deadline
- Banker or any caller may close the table once close conditions are met
- Engine requests and stores one VRF-backed baccarat round
- Any caller may settle a closed, resolved table

## Randomness / Proof Source

- Source: VRF-backed single baccarat round resolved by `CheminDeFerEngine`
- The round itself uses the same automated baccarat tableau as the solo baccarat engine

## Rules And Economic Parameters

- Banker escrow is burned up front on table open
- Taker amounts are burned when accepted
- Taker capacity is bounded by:
  - `playerTakeCap = bankerEscrow * 1e18 / BANKER_RISK_PER_PLAYER_WAD`
- Matched banker risk is:
  - `matchedBankerRisk = totalPlayerTake * BANKER_RISK_PER_PLAYER_WAD / 1e18`
- `BANKER_RISK_PER_PLAYER_WAD = 1_027_677_102_818_402_306`
- Unmatched banker escrow is refunded on settlement
- Developer accrual uses `matchedBankerRisk + totalPlayerTake`

## Lifecycle / State Progression

1. Banker opens table
2. Join window opens for takers
3. Takers join until:
   - the join deadline expires, or
   - the player take cap is filled
4. Banker may close early once at least one taker exists
5. Any caller may force-close after the join deadline if takers exist
6. Engine requests VRF and resolves one baccarat round
7. Any caller may settle the closed and resolved table

## Settlement Formulas And Precedence

- `matchedExposure = matchedBankerRisk + totalPlayerTake`

Outcome handling:

- Banker win:
  - banker receives `unmatchedBankerRefund + matchedExposure`
  - takers receive `0`
- Tie:
  - banker receives `unmatchedBankerRefund + matchedBankerRisk`
  - each taker is refunded exactly their take
- Player win:
  - banker receives `unmatchedBankerRefund`
  - takers split `matchedExposure` pro rata by contribution
  - final taker receives the remainder to avoid rounding loss

## Timeouts, Forced Resolution, And Cancellation

- Join window is enforced by `JOIN_WINDOW`
- A table with no takers may be canceled by the banker before close, or by anyone after join expiry
- Closed tables cannot be reopened
- Settlement waits for VRF resolution; there is no alternative timeout path once the request is in flight

## Observability

Clients rely on:

- `tables(tableId)`
- `getTakers(tableId)`
- `getTakerAmount(tableId, taker)`
- `playerTakeCap(bankerEscrow)`
- `matchedBankerRisk(totalPlayerTake)`
- `engine.getRound(tableId)`
- table lifecycle and resolution events

## Implementation Notes

- This spec matches the current implementation
- The table is banker-opened and many-taker, but settlement is still one-shot rather than continuous table play
