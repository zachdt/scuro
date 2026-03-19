# SlotMachineEngine

## Purpose

`SlotMachineEngine` resolves one atomic slot spin per request from a governed on-chain preset. It owns slot preset registration, seed-based outcome resolution, bonus-family execution, and the solo settlement tuple consumed by the controller.

## Caller Model

- An authorized controller calls `requestSpin`
- The configured VRF coordinator calls `rawFulfillRandomWords`
- Governance-managed actors register presets and toggle preset activity
- Clients read presets, spins, results, and settlement data directly

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `PRESET_MANAGER_ROLE`

## Constructor And Config

- `constructor(admin, catalogAddress, vrfCoordinatorAddress)`
- Exposes `catalog()`, `VRF_COORDINATOR`, aggregate spin stats, and `presetActive`

## Public API

- `catalog()`
- `engineType()`
- `registerPreset(config)`
- `setPresetActive(presetId, active)`
- `requestSpin(player, stake, presetId, playRef)`
- `rawFulfillRandomWords(spinId, randomWords)`
- `getPreset(presetId)`
- `getPresetSummary(presetId)`
- `getSpin(spinId)`
- `getSpinResult(spinId)`
- `getSettlementOutcome(spinId)`

## Events

- `PresetRegistered`
- `PresetActiveSet`
- `SpinRequested`
- `BaseGameResolved`
- `FreeSpinsResolved`
- `PickBonusResolved`
- `HoldAndSpinResolved`
- `JackpotAwarded`
- `SpinResolved`

## State And Lifecycle Notes

- The engine type is `keccak256("SLOT_MACHINE")`
- Presets are immutable once registered; lifecycle changes happen through `setPresetActive`
- Resolution supports a ways-based base game plus bounded `free spins`, `pick bonus`, and `hold-and-spin`
- Runtime checks enforce both payout caps and total-event caps per preset

## Revert Conditions

- Missing `PRESET_MANAGER_ROLE` for preset mutation
- Unauthorized controller or wrong coordinator
- Inactive or unknown preset
- Stake outside preset bounds
- Module inactive on fulfillment
- Unknown or already-resolved spin
- Runtime event-cap or payout-cap overflow

## Test Anchors

- `test/SlotMachineController.t.sol`
- `test/invariants/SlotMachineInvariants.t.sol`
- `test/e2e/SmokeE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
