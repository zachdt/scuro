# CheminDeFerController

## Purpose

`CheminDeFerController` runs banker-opened, many-taker baccarat tables, closes them into a one-shot engine resolution, and settles matched exposure through `ProtocolSettlement`.

For the canonical product rules and economics, see the [Chemin de Fer session spec](../session-specs/chemin-de-fer.md).

## Caller Model

- Bankers open tables and may close or cancel them
- Permissionless takers join open tables through `take`
- Any caller may force-close expired join windows and settle resolved tables

## Roles And Permissions

- No local roles
- Launch and settlement gating are delegated to `GameCatalog`

## Constructor And Config

- `constructor(settlementAddress, catalogAddress, engineAddress, joinWindow)`
- Exposes `settlement()`, `catalog()`, `engine()`, and `JOIN_WINDOW`

## Public API

- `settlement()`
- `catalog()`
- `engine()`
- `getTakers(tableId)`
- `getTakerAmount(tableId, taker)`
- `playerTakeCap(bankerEscrow)`
- `matchedBankerRisk(totalPlayerTake)`
- `openTable(bankerMaxBet, playRef, expressionTokenId)`
- `take(tableId, amount)`
- `closeTable(tableId)`
- `forceCloseTable(tableId)`
- `cancelTable(tableId)`
- `settle(tableId)`

## Events

- `TableOpened`
- `TableTaken`
- `TableClosed`
- `TableCanceled`
- `TableSettled`

## State And Lifecycle Notes

- Banker escrow is burned up front on `openTable`
- Taker contributions are burned when accepted
- Closing a table snapshots matched banker risk, unmatched banker refund, and then requests engine resolution
- Settlement distributes matched exposure according to the baccarat outcome and accrues developer rewards from matched exposure

## Revert Conditions

- Module inactive
- Invalid banker max bet or taker amount
- Unknown, closed, or already-settled table
- Join window violations
- Taking above cap
- Cancel when takers are present
- Settlement before engine resolution

## Test Anchors

- `test/CheminDeFerController.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
