# Slot Machine Session Spec

## Product Identity And Session Owner

- Product: governed slot machine
- Session owner: `SlotMachineController`
- Session model: one preset-selected spin resolved from one VRF request

## Session Creation Inputs And Actor Roles

- Player supplies `stake`, `presetId`, `playRef`, and `expressionTokenId`
- Controller burns the stake before spin launch
- Governance-managed actors register and activate presets
- VRF coordinator resolves the spin
- Any caller may settle a resolved but unfinalized spin

## Randomness Source

- Source: VRF-backed randomness
- Preset configuration is governed and immutable once registered
- All math for a spin comes from the selected preset and the single randomness seed

## Rules And Economic Parameters

- The product is preset-driven rather than rule-driven
- Each preset defines:
  - allowed stake range
  - ways-based base game math
  - enabled bonus families
  - payout caps
  - total event caps
- Supported bonus families are:
  - free spins
  - pick bonus
  - hold-and-spin
- The controller pays exactly the engine-reported payout

## Lifecycle / State Progression

1. Player calls `spin(...)`
2. Controller burns the stake
3. Engine validates the preset and requests randomness
4. VRF fulfills the request
5. Engine resolves base game and any bounded bonus-family chain
6. Controller settles immediately when fulfillment is synchronous, or any caller may later call `settle(spinId)`

## Settlement Formulas And Precedence

- Preset math determines the gross payout
- Runtime checks enforce payout caps and total-event caps before the final result is accepted
- Developer accrual uses the original burned stake, not the resolved payout

## Timeouts, Forced Resolution, And Cancellation

- No player decision phases after spin request
- No cancellation after randomness request
- Delayed VRF environments use explicit later settlement rather than timeout logic

## Observability

Clients rely on:

- `spinSettled(spinId)`
- `spinExpressionTokenId(spinId)`
- `getPresetSummary(presetId)` and `getPreset(presetId)`
- `getSpin(spinId)` and `getSpinResult(spinId)`
- `getSettlementOutcome(spinId)`
- preset and spin lifecycle events emitted by the engine and controller

## Implementation Notes

- This spec matches the current implementation
- Off-chain themes and art should stay keyed separately from the on-chain preset id and preset hash
