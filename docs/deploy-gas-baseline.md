# Deploy Gas Baseline

- Anvil reference gas limit: default
- This baseline uses the staged beta deploy path, not `DeployLocal`.
- The canonical staged path deploys core, number-picker, slot, then finalizes expression ownership.

## Bytecode Size Baseline

| Contract | Constructor Bytecode (bytes) | Runtime Bytecode (bytes) |
| --- | ---: | ---: |
| NumberPickerEngine | 3541 | 3336 |
| SlotMachineEngine | 21764 | 21169 |
| NumberPickerAdapter | 2811 | 2543 |
| SlotMachineController | 2920 | 2651 |

## Staged Deploy Gas Baseline

| Stage Action | Gas Used |
| --- | ---: |
| NumberPicker:Engine | 775898 |
| NumberPicker:Adapter | 604414 |
| NumberPicker:RegisterModule | 190451 |
| SlotMachine:Engine | 4706310 |
| SlotMachine:Controller | 627881 |
| SlotMachine:RegisterModule | 190451 |
| SlotMachine:RegisterPreset | 928862 |
| SlotMachine:RegisterPreset | 928862 |
| SlotMachine:RegisterPreset | 928862 |
| SlotMachine:RegisterPreset | 928874 |

- Full staged beta deploy total gas: `25244298`
