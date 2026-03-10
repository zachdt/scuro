# Scuro Protocol Architecture

Scuro is a shared settlement and governance layer that hosts multiple game-specific controllers and engines behind a single protocol asset. The current implementation includes a VRF-backed solo example plus poker and blackjack examples that rely on Groth16 proof verification, with developer attribution handled through transferable expression NFTs.

Next step after this page: use [Local Deployment and Testing](./local-deployment-testing.md) when you need commands, deployment workflow, or suite selection.

## High-Level Architecture

```mermaid
graph TB
    subgraph GovernanceLayer [Governance Layer]
        Governor[ScuroGovernor]
        Timelock[TimelockController]
    end

    subgraph UserLayer [User Layer]
        Player[Players / Participants]
        Devs[Developers / Distributors]
    end

    subgraph ControllerLayer [Controller Layer]
        Solo[NumberPickerAdapter]
        PvP[PvPController]
        Tourn[TournamentController]
        BjCtrl[BlackjackController]
    end

    subgraph ServiceLayer [Protocol Service Layer]
        Settlement[ProtocolSettlement]
        Registry[GameEngineRegistry]
        Expressions[DeveloperExpressionRegistry]
        Rewards[DeveloperRewards]
    end

    subgraph TokenLayer [Token Ecosystem]
        Token[ScuroToken ERC20]
        Stake[ScuroStakingToken sSCU]
    end

    subgraph EngineLayer [Engine Layer]
        NumberPicker[NumberPickerEngine]
        Poker[SingleDraw2To7Engine]
        Blackjack[SingleDeckBlackjackEngine]
    end

    subgraph ExternalLayer [External Integrations]
        VRF[VRF Coordinator]
        ZK[Groth16 Verifiers]
    end

    Player --> Solo
    Player --> PvP
    Player --> Tourn
    Player --> BjCtrl
    Player --> Stake
    Player --> Governor
    Devs --> Expressions

    Governor --> Timelock
    Governor --> Stake
    Timelock --> Registry
    Timelock --> Rewards
    Timelock --> Expressions

    Solo --> Settlement
    Solo --> Registry
    Solo --> NumberPicker

    PvP --> Settlement
    PvP --> Registry
    PvP --> Poker

    Tourn --> Settlement
    Tourn --> Registry
    Tourn --> Poker

    BjCtrl --> Settlement
    BjCtrl --> Registry
    BjCtrl --> Blackjack

    Settlement --> Token
    Settlement --> Registry
    Settlement --> Expressions
    Settlement --> Rewards
    Rewards --> Token
    Stake --> Token

    NumberPicker --> VRF
    Poker --> ZK
    Blackjack --> ZK
```

## Layer Breakdown

### Governance and tokens

- `ScuroToken` (`SCU`) is the protocol asset used for wagers, rewards, and developer payouts.
- `ScuroStakingToken` (`sSCU`) wraps staked SCU and provides governance voting power.
- `ScuroGovernor` plus `TimelockController` govern live protocol configuration such as developer reward epoch duration and expression moderation roles.

### Controllers

- `NumberPickerAdapter` handles solo VRF-backed play and immediate settlement finalization.
- `TournamentController` creates tournaments, starts poker matches, and settles reported tournament outcomes.
- `PvPController` creates direct two-player poker sessions and settles completed matches.
- `BlackjackController` opens blackjack hands, burns any extra wager for doubles or splits, and settles completed hands.
- Every gameplay entrypoint carries an `expressionTokenId`; multi-step controllers persist it so settlement can attribute rewards later.

### Protocol services

- `ProtocolSettlement` is the only protocol-level contract allowed to burn player wagers, mint player rewards, and accrue developer rewards.
- `GameEngineRegistry` stores engine metadata, developer reward rates, compatibility flags, verifier/config references, and active status.
- `DeveloperExpressionRegistry` is a permissionless ERC721 registry for developer-owned engine expressions bound to `engineType`.
- `DeveloperRewards` accumulates developer inflation by epoch and handles post-close claims.

### Engines and integrations

- `NumberPickerEngine` is the simple solo engine and depends on a VRF coordinator mock in local and dev flows.
- `SingleDraw2To7Engine` is the shared poker engine for tournament and PvP flows. Controllers initialize games while a zk coordinator proves the initial deal, draw resolution, and showdown.
- `SingleDeckBlackjackEngine` is the solo zk blackjack engine. The controller opens sessions while a zk coordinator proves the initial deal, action resolution, and showdown.
- Poker and blackjack both depend on Groth16 verifier bundles wired into the deployed stack.

## Value And Control Flow

- Players enter through controllers or the staking token, not through settlement directly.
- Controllers consult the registry to ensure an engine is active and compatible with the requested play mode.
- Engines own rules, proof or randomness requirements, and game-specific state transitions.
- Gameplay calls supply an `expressionTokenId`; multi-step flows store it first and reuse it at final settlement.
- Settlement centralizes value movement by burning wagers, minting payouts, and recording developer reward accruals.
- Settlement enforces engine active, expression active, and engine-type compatibility at accrual time.
- Developer accrual follows the current owner of the expression NFT when settlement books activity.
- Governance modifies live protocol settings through the governor and timelock rather than per-engine manual intervention.

## Code Map

- `src/ScuroToken.sol`, `src/ScuroStakingToken.sol`, `src/ScuroGovernor.sol`: token and governance primitives.
- `src/ProtocolSettlement.sol`, `src/GameEngineRegistry.sol`, `src/DeveloperExpressionRegistry.sol`, `src/DeveloperRewards.sol`: shared protocol service layer.
- `src/controllers/`: controller and adapter entrypoints for solo, tournament, PvP, and blackjack flows.
- `src/engines/`: game-specific rule engines.
- `src/verifiers/` and `zk/`: verifier bundles, generated verifier contracts, circuits, fixtures, and zk artifacts.
- `script/DeployLocal.s.sol` and `script/e2e_deploy_smoke.sh`: local stack deployment and smoke verification entrypoints.
- `test/e2e/`: end-to-end scenario suites and coverage matrix.

## Operational Notes

- Registry deactivation blocks new sessions and also blocks later settlement flows that need developer accrual until the engine is reactivated.
- Expression compatibility is enforced when settlement books accrual, so a deactivated or mismatched expression can surface at settlement time for long-running flows.
- Expression NFTs are transferable; long-running sessions follow the expression owner at final settlement.
- The zk-backed engines still rely on an off-chain coordinator for proof generation and submission.
