# Scuro

Scuro is an on-chain gaming protocol built around shared economic infrastructure instead of one-off game contracts. A single protocol token powers play, staking, governance, and developer rewards; controllers route user actions into registered game engines; a developer-expression registry carries attribution; and a shared settlement layer burns wagers, mints payouts, and books developer accruals under governance-controlled policy.

## Core Primitives

- `ScuroToken` (`SCU`) is the protocol asset used for wagers, rewards, and developer payouts.
- `ScuroStakingToken` (`sSCU`) wraps staked SCU and represents governance voting power.
- `ProtocolSettlement` is the only protocol-level contract that moves value on behalf of controllers.
- `GameEngineRegistry` records which engines are live, what verifier/config they depend on, their compatibility flags, and their developer reward rates.
- `DeveloperExpressionRegistry` is a permissionless ERC721 registry for developer-owned engine expressions used for reward attribution.
- `DeveloperRewards` tracks inflationary developer rewards by epoch and handles claims after an epoch closes.
- `ScuroGovernor` with `TimelockController` governs live protocol configuration such as reward timing and expression moderation roles.

## How Scuro Flows

- Players bring SCU into gameplay, staking, and governance through controllers and the staking token rather than interacting with settlement logic directly.
- Gameplay entrypoints carry an `expressionTokenId` so developer attribution is explicit for each solo, PvP, tournament, or blackjack session.
- Controllers and adapters orchestrate session lifecycle for different play modes, while engines own game-specific rules and proof or randomness requirements.
- The registry is the policy layer between orchestration and game logic: it decides which engines are active, which play modes they support, and what developer reward rate applies.
- Settlement is the single value path for wager burns, payout minting, and developer reward accrual. Reward attribution follows the current `ownerOf(expressionTokenId)` when settlement books accrual.
- Governance updates protocol configuration through the governor and timelock instead of per-engine admin flows.

## Current Implementation Examples

- `NumberPickerAdapter` + `NumberPickerEngine` provide a simple solo flow backed by VRF-style randomness.
- `TournamentController` and `PvPController` both route into `SingleDraw2To7Engine`, showing how one engine can support tournament and head-to-head play.
- `BlackjackController` + `SingleDeckBlackjackEngine` provide a solo blackjack flow with Groth16 proof verification.
- The local stack also seeds example expression NFTs for number picker, poker, and blackjack so the full developer-attribution path is exercised in tests and deploy smoke flows.

## Builder Quickstart

- `forge build` compiles the contracts. See the [command quick reference](./docs/local-deployment-testing.md#command-quick-reference).
- `forge test --offline` runs the full suite in this environment. See the [recommended order](./docs/local-deployment-testing.md#recommended-order).
- `./script/e2e_deploy_smoke.sh` runs the highest-signal local integration check. See [Deploy Smoke](./docs/local-deployment-testing.md#deploy-smoke).

For prerequisites, zk artifact guidance, manual deployment, and suite selection, see [Local Deployment and Testing](./docs/local-deployment-testing.md).

## Documentation Map

- [Docs index](./docs/README.md): short guide to the internal documentation set.
- [Protocol architecture](./docs/protocol-architecture.md): full component diagram, developer-expression flow, and code map.
- [Local deployment and testing](./docs/local-deployment-testing.md): setup, build, deploy, smoke, and suite selection.
- [E2E scenario matrix](./test/e2e/MATRIX.md): coverage gate for the end-to-end suite.

## License

Unless a file header or [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) says otherwise, this repository is proprietary and public for inspection only. It is not licensed for personal, internal, academic, or commercial use. See [LICENSE](./LICENSE).
