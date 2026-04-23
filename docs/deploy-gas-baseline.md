# Deploy Gas Baseline

- Anvil reference gas limit: `100000000`
- This baseline uses the staged beta deploy path, not `DeployLocal`.
- The canonical staged path deploys core, number-picker, slot, then finalizes expression ownership.

## Bytecode Size Baseline

| Contract | Constructor Bytecode (bytes) | Runtime Bytecode (bytes) |
| --- | ---: | ---: |
| GameDeploymentFactory | pending regeneration | pending regeneration |
| SoloModuleDeployer | pending regeneration | pending regeneration |
| NumberPickerEngine | pending regeneration | pending regeneration |
| SlotMachineEngine | pending regeneration | pending regeneration |
| NumberPickerAdapter | pending regeneration | pending regeneration |
| SlotMachineController | pending regeneration | pending regeneration |

## Staged Deploy Gas Baseline

Run `bash script/aws/generate_deploy_baseline.sh` on a machine with Anvil available to refresh this table.
