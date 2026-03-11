# Scuro

Scuro is a next-generation on-chain gaming protocol designed as a shared economic backbone for decentralized games. Unlike traditional models that rely on isolated, one-off contracts, Scuro provides a unified infrastructure for play, staking, governance, and developer incentives—allowing game developers to focus on logic while inheriting a robust, secure settlement layer.

## Core Primitives

A single protocol token (`SCU`) powers the entire ecosystem, ensuring deep liquidity and shared utility across all hosted modules.

- **`ScuroToken` (`SCU`)**: The native protocol asset used for wagers, rewards, and developer payouts.
- **`ScuroStakingToken` (`sSCU`)**: A liquid representation of staked SCU that confers governance voting power.
- **`ProtocolSettlement`**: The central authority for value movement, managing wagers, payouts, and accruals.
- **`GameCatalog`**: A registry of authorized game modules, engines, and verifiers, enforcing protocol-level policy.
- **`GameDeploymentFactory`**: A streamlined tool for deploying and registering new controller/engine bundles.
- **`DeveloperExpressionRegistry`**: An ERC721 registry for developer-owned "expressions"—logical identities used for reward attribution.
- **`DeveloperRewards`**: An automated system that tracks and distributes inflationary rewards to developers based on activity.
- **`ScuroGovernor` & `TimelockController`**: The decentralized governance layer that manages global protocol parameters.

## The Scuro Lifecycle

The protocol abstracts complex settlement logic away from the player, providing a seamless experience across diverse game types.

1.  **Entry**: Players engage with game-specific **Controllers** using `SCU`. They don't interact with settlement logic directly; instead, they enter via gameplay or staking.
2.  **Attribution**: Every session is tagged with an `expressionTokenId`. This ensures that the original developers are rewarded for every interaction their logic facilitates.
3.  **Execution**: **Engines** enforce game-specific rules. Whether it's a VRF-backed solo game or a ZK-proven poker match, the engine ensures integrity while the controller manages the session flow.
4.  **Settlement**: When a game concludes, the controller calls the shared **Settlement** layer. Settlement validates the module's status via the **Catalog**, moves value, and books developer rewards to the current holder of the expression NFT.
5.  **Governance**: The community uses the **Governor** to tune reward rates, manage the catalog, and guide the protocol's evolution without needing to redeploy core logic.

## Supported Game Modules

Scuro's architecture is flexible enough to support a wide array of gaming experiences out of the box:

- **Solo Randomness**: `NumberPicker` demonstrates simple VRF-backed gameplay.
- **Competitive Poker**: `TournamentController` and `PvPController` power poker sessions with Groth16 proof verification.
- **ZK Blackjack**: `BlackjackController` offers a secure solo blackjack experience using zero-knowledge proofs.
- **Developer Sandbox**: The local stack includes example expression NFTs, allowing developers to test the full attribution path immediately.

## Developer Quickstart

Get the Scuro protocol running locally in minutes:

- **Build**: `forge build` compiles the smart contracts.
- **Test**: `forge test --offline` runs the comprehensive test suite.
- **Smoke Check**: `./script/e2e_deploy_smoke.sh` performs a full-stack local integration test.

For detailed setup instructions and ZK artifact guidance, see [Local Deployment and Testing](./docs/local-deployment-testing.md).

## Documentation Map

- **[Docs Index](./docs/README.md)**: Your entry point to the full documentation suite.
- **[Protocol Architecture](./docs/protocol-architecture.md)**: Deep dive into the system design, component layers, and code map.
- **[Local Deployment](./docs/local-deployment-testing.md)**: Technical guide for environment setup, building, and running tests.
- **[E2E Scenario Matrix](./test/e2e/MATRIX.md)**: A detailed mapping of user stories to automated test cases.

## License

Unless otherwise specified in a file header or [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md), this repository is proprietary and provided for inspection only. See [LICENSE](./LICENSE) for details.
