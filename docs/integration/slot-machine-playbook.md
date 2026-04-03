# Slot Machine Playbook

## Purpose

This playbook is the minimum governed-slot flow a Node or Rust API should support.

Product rules and economics live in the [Slot Machine session spec](../session-specs/slot-machine.md).

## Transaction Sequence

1. Ensure the player has approved `ProtocolSettlement` for the stake amount.
2. Optionally preflight `GameCatalog.isLaunchableController(slotMachineController)`.
3. Read the target preset through `getPresetSummary(presetId)` if the client needs volatility or cap metadata.
4. Call `SlotMachineController.spin(stake, presetId, playRef, expressionTokenId)`.
5. Record the returned `spinId`.
6. Watch engine and controller events for preset selection, feature resolution, and final settlement.
7. If local VRF is delayed rather than auto-callback, call `settle(spinId)` once `getSettlementOutcome(spinId).completed` is true.

## Read Sequence

- `spinExpressionTokenId(spinId)` and `spinSettled(spinId)` on the controller
- `getPresetSummary(presetId)` and `getPreset(presetId)` on the engine
- `getSpin(spinId)` and `getSpinResult(spinId)` on the engine
- `getSettlementOutcome(spinId)` on the engine interface shape

## Client Notes

- Presets are governed on-chain math packages; clients should treat `presetId` as the core slot configuration selector
- Off-chain theme, art, and authored descriptions should be keyed separately from on-chain preset ids and hashes
- The controller burns the stake before randomness is requested
- Developer accrual uses the original stake amount as activity
- `GameDeploymentFactory` supports slot deployment, but `script/DeployLocal.s.sol` has not yet been updated to emit slot addresses in the default local bootstrap flow

## Relevant References

- [Slot Machine Session Spec](../session-specs/slot-machine.md)
- [SlotMachineController](../reference/slot-machine-controller.md)
- [SlotMachineEngine](../reference/slot-machine-engine.md)
- [GameDeploymentFactory](../reference/game-deployment-factory.md)
