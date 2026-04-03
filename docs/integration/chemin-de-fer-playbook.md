# Chemin de Fer Playbook

## Purpose

This playbook covers the banker-opened many-taker baccarat flow.

Product rules and economics live in the [Chemin de Fer session spec](../session-specs/chemin-de-fer.md).

## Transaction Sequence

1. Banker ensures `ProtocolSettlement` approval for the intended escrow.
2. Banker calls `openTable(bankerMaxBet, playRef, expressionTokenId)`.
3. Takers ensure approval and call `take(tableId, amount)` during the join window.
4. Banker may call `closeTable(tableId)` once at least one taker has joined.
5. If the join window expires first, any caller may call `forceCloseTable(tableId)`.
6. Engine requests VRF and stores the baccarat outcome.
7. Any caller calls `settle(tableId)` once `engine.getRound(tableId).resolved` is true.
8. If no takers ever joined, banker or any caller after join expiry may call `cancelTable(tableId)`.

## Read Sequence

- `tables(tableId)` on the controller
- `getTakers(tableId)` and `getTakerAmount(tableId, taker)` on the controller
- `playerTakeCap(bankerEscrow)` and `matchedBankerRisk(totalPlayerTake)` on the controller
- `getRound(tableId)` on the engine

## Client Notes

- The controller owns value movement, matched-exposure math, and pro-rata taker payouts.
- The engine only stores the resolved baccarat round.
- Join-window expiry is a controller concern; VRF delay after close is an engine-resolution concern.

## Relevant References

- [Chemin de Fer Session Spec](../session-specs/chemin-de-fer.md)
- [CheminDeFerController](../reference/chemin-de-fer-controller.md)
- [CheminDeFerEngine](../reference/chemin-de-fer-engine.md)
