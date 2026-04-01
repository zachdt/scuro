# Deployment and Config Guide

This guide defines the deployment metadata that SDKs should consume from local deployment output and from `docs/generated/protocol-manifest.json`.

## Deployment Sources

- `script/DeployLocal.s.sol`: canonical local deployment and bootstrap flow
- `script/e2e_deploy_smoke.sh`: smoke validation that parses the deploy output labels
- `docs/generated/protocol-manifest.json`: machine-readable contract identity and default config metadata

## Required Output Labels

Clients consuming local deployment output should expect these labels:

- Core: `ScuroToken`, `ScuroStakingToken`, `TimelockController`, `ScuroGovernor`, `GameCatalog`, `GameDeploymentFactory`, `DeveloperExpressionRegistry`, `DeveloperRewards`, `ProtocolSettlement`
- Controllers: `NumberPickerAdapter`, `TournamentController`, `PvPController`, `BlackjackController`
- Engines: `NumberPickerEngine`, `TournamentPokerEngine`, `PvPPokerEngine`, `SingleDeckBlackjackEngine`
- Verifiers: `TournamentPokerVerifierBundle`, `PvPPokerVerifierBundle`, `BlackjackVerifierBundle`
- Module ids: `NumberPickerModuleId`, `TournamentPokerModuleId`, `PvPPokerModuleId`, `BlackjackModuleId`
- Seed actors and expressions: `Admin`, `Player1`, `Player2`, `SoloDeveloper`, `PokerDeveloper`, `NumberPickerExpressionTokenId`, `PokerExpressionTokenId`, `BlackjackExpressionTokenId`

Current local-script note:
- `GameDeploymentFactory` supports `SoloFamily.SlotMachine`, but `script/DeployLocal.s.sol` does not yet emit slot controller/engine addresses, module ids, or expression-token labels in the canonical local bootstrap output.

## Local Default Configs

| Module family | Defaults |
| --- | --- |
| NumberPicker | auto-callback VRF mock, `developerRewardBps = 500`, `configHash = keccak256("number-picker-auto")` |
| Slot machine | factory-supported with `SlotDeployment(vrfCoordinator, configHash, developerRewardBps)`; canonical local deploy script still pending |
| Tournament poker | `smallBlind = 10`, `bigBlind = 20`, `blindEscalationInterval = 180`, `actionWindow = 60`, `developerRewardBps = 1000` |
| PvP poker | same defaults as tournament poker, with `configHash = keccak256("single-draw-2-7-pvp")` |
| Blackjack | `defaultActionWindow = 60`, `developerRewardBps = 500`, `configHash = keccak256("single-deck-blackjack-zk-v2")` |

## SDK Guidance

- Use deployment labels as the first lookup key, then normalize them into SDK-specific config objects.
- Persist `engineType`, `configHash`, `moduleId`, and verifier bundle address together so client logic can route proofs and expression compatibility checks correctly.
- Treat local deployment defaults as examples, not protocol-wide constants. Always prefer chain-specific deployment metadata when available.
