# Deployment And Config

The canonical deployment surface emits labels for core contracts, the two solo modules, seed actors, expression ids, and slot preset ids.

## Required Labels

- Core: `ScuroToken`, `ScuroStakingToken`, `TimelockController`, `ScuroGovernor`, `GameCatalog`, `DeveloperExpressionRegistry`, `DeveloperRewards`, `ProtocolSettlement`
- Controllers: `NumberPickerAdapter`, `SlotMachineController`
- Engines: `NumberPickerEngine`, `SlotMachineEngine`
- Module ids: `NumberPickerModuleId`, `SlotMachineModuleId`
- Slot presets: `SlotBasePresetId`, `SlotFreePresetId`, `SlotPickPresetId`, `SlotHoldPresetId`
- Actors and expressions: `Admin`, `Player1`, `Player2`, `SoloDeveloper`, `NumberPickerExpressionTokenId`, `SlotMachineExpressionTokenId`

## Defaults

| Module | Defaults |
| --- | --- |
| NumberPicker | `configHash = keccak256("number-picker-auto")`, `developerRewardBps = 500` |
| SlotMachine | `configHash = keccak256("slot-machine-auto")`, `developerRewardBps = 500`, presets `base`, `free`, `pick`, `hold` |

Clients should persist `engineType`, `configHash`, `moduleId`, controller, engine, and expression ids together.
