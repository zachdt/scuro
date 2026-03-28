# Deploy Gas Baseline

- Anvil reference gas limit: `100000000`
- This baseline uses the staged beta deploy path, not `DeployLocal`.
- The previously failing tx was approximately `32194656` gas, which is below the Anvil ceiling and points to deployment architecture size rather than a simple chain gas-cap mismatch.

## Bytecode Size Baseline

| Contract | Constructor Bytecode (bytes) | Runtime Bytecode (bytes) |
| --- | ---: | ---: |
| GameDeploymentFactory | 6398 | 5576 |
| SoloModuleDeployer | 41061 | 41034 |
| BlackjackModuleDeployer | 30761 | 30734 |
| PokerModuleDeployer | 36017 | 35990 |
| CheminDeFerModuleDeployer | 13466 | 13439 |
| PokerVerifierBundle | 3675 | 3083 |
| BlackjackVerifierBundle | 3944 | 3352 |
| PokerInitialDealVerifier | 2591 | 2564 |
| PokerDrawResolveVerifier | 2775 | 2748 |
| PokerShowdownVerifier | 2096 | 2069 |
| BlackjackInitialDealVerifier | 5204 | 5177 |
| BlackjackActionResolveVerifier | 5204 | 5177 |
| BlackjackShowdownVerifier | 2937 | 2910 |
| SingleDraw2To7Engine | 12264 | 11915 |
| SingleDeckBlackjackEngine | 9029 | 8738 |

The current regression thresholds for these deployment artifacts live in [`deploy-size-thresholds.json`](/Users/zachdt/work/scuro/script/aws/deploy-size-thresholds.json). The staged deploy gas thresholds live in [`deploy-gas-thresholds.json`](/Users/zachdt/work/scuro/script/aws/deploy-gas-thresholds.json). The deploy gas report workflow fails on gas regressions first and bytecode growth second.

## Staged Deploy Gas Baseline

Staged deploy gas rows were not captured in this environment because local Foundry script execution hit a macOS runtime crash while resolving transport/proxy state. Run [`generate_deploy_baseline.sh`](/Users/zachdt/work/scuro/script/aws/generate_deploy_baseline.sh) on Linux or in CI to populate them.
