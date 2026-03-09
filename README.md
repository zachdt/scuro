# Scuro

Scuro is a generalized on-chain gaming protocol built around a shared token, shared settlement layer, creator rewards, and governance-controlled protocol configuration.

The root of this repository is the canonical protocol package. Older protocol-specific codebases live under `archive/` and are not part of the active surface area.

## What Scuro Includes

- One protocol token for gameplay, staking, governance, and rewards: `ScuroToken` (`SCU`)
- One staking/voting asset: `ScuroStakingToken` (`sSCU`)
- Governance with `ScuroGovernor` + `TimelockController`
- Shared protocol services:
  - `ProtocolSettlement`
  - `GameEngineRegistry`
  - `CreatorRewards`
- Controllers:
  - `TournamentController`
  - `PvPController`
  - `NumberPickerAdapter`
- Engines:
  - `NumberPickerEngine`
  - `SingleDraw2To7Engine`
- Local deployment and smoke tooling:
  - `script/DeployLocal.s.sol`
  - `script/e2e_deploy_smoke.sh`
- A layered end-to-end suite under `test/e2e`

## Protocol Model

### Token and settlement

`ScuroToken` is the economic unit of the protocol.

- Players use SCU for wagers and entry fees.
- Settlement burns wagers and mints rewards.
- Creator rewards are denominated in SCU.
- Governance voting power comes from staked SCU (`sSCU`), not raw wallet balances.

`ProtocolSettlement` is the only protocol-level contract that controllers use for value movement.

- Burns player wagers through allowance-based `burnFrom`
- Mints player rewards
- Records creator accruals based on engine metadata

### Creator rewards

`CreatorRewards` tracks inflationary creator rewards by epoch.

- Settlement accrues creator rewards against the current epoch.
- Epochs close on a time schedule.
- Creators claim rewards after epoch close.
- Reward rates are defined per engine instance in the registry.

### Registry

`GameEngineRegistry` is the routing and policy layer for engines.

Each engine entry stores:

- engine type
- creator address
- verifier address
- config hash
- creator reward bps
- active flag
- compatibility flags for solo / PvP / tournament

### Governance

`ScuroGovernor` + `TimelockController` govern live protocol configuration.

Current governance-tested flows include:

- staking and delegation
- proposal creation
- voting
- queue / execute through timelock
- live parameter updates such as creator epoch duration

### Controllers and engines

Scuro separates orchestration from game logic.

- `TournamentController` manages tournament-style sessions for registered tournament engines.
- `PvPController` manages direct competitive sessions for registered PvP engines.
- `NumberPickerAdapter` is the solo-play entrypoint for the VRF-backed number picker engine.

Current example engines:

- `NumberPickerEngine`
  - single-player
  - burn wager, resolve randomness, mint reward if won
- `SingleDraw2To7Engine`
  - 2-player single-draw poker
  - supports tournament and PvP controller flows
  - includes proof-gated draw/showdown hooks for generalized poker ZK integration

## Architecture

See [architecture_overview.md](./architecture_overview.md) for the higher-level diagram. The active contract graph is:

```mermaid
graph TB
    Player["Players"]
    Gov["ScuroGovernor"]
    Time["TimelockController"]
    Token["ScuroToken"]
    Stake["ScuroStakingToken"]
    Settle["ProtocolSettlement"]
    Registry["GameEngineRegistry"]
    Rewards["CreatorRewards"]
    Tour["TournamentController"]
    PvP["PvPController"]
    Solo["NumberPickerAdapter"]
    Num["NumberPickerEngine"]
    Poker["SingleDraw2To7Engine"]

    Player --> Stake
    Player --> Tour
    Player --> PvP
    Player --> Solo

    Stake --> Token
    Gov --> Time
    Gov --> Stake

    Tour --> Settle
    Tour --> Registry
    PvP --> Settle
    PvP --> Registry
    Solo --> Settle
    Solo --> Registry

    Settle --> Token
    Settle --> Registry
    Settle --> Rewards

    Registry --> Num
    Registry --> Poker
```

## Repository Layout

```text
.
├── foundry.toml
├── src/
│   ├── ScuroToken.sol
│   ├── ScuroStakingToken.sol
│   ├── ScuroGovernor.sol
│   ├── ProtocolSettlement.sol
│   ├── GameEngineRegistry.sol
│   ├── CreatorRewards.sol
│   ├── controllers/
│   ├── engines/
│   ├── interfaces/
│   ├── libraries/
│   └── mocks/
├── test/
│   ├── ProtocolCore.t.sol
│   ├── NumberPickerAdapter.t.sol
│   ├── TournamentController.t.sol
│   └── e2e/
├── script/
│   ├── DeployLocal.s.sol
│   └── e2e_deploy_smoke.sh
├── lib/
└── archive/
```

### Active vs archived

- `src/`, `test/`, `script/`, `foundry.toml`, and `lib/` are the active protocol package.
- `archive/` contains legacy protocol directories kept for reference only.

## Getting Started

### Prerequisites

- Foundry (`forge`, `cast`, `anvil`)
- `bash` for the deploy smoke helper

### Build

```bash
forge build
```

### Run all tests

Use `--offline` in this environment. It avoids a local Foundry issue around external trace/signature lookup.

```bash
forge test --offline
```

### Run only the layered E2E suite

```bash
forge test --match-path 'test/e2e/*.t.sol' --offline
```

## Local Deployment

### Deploy the full local stack manually

Start Anvil in one terminal:

```bash
anvil
```

Deploy in another:

```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
forge script script/DeployLocal.s.sol:DeployLocal \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

The local deploy script does the following:

- deploys the token, staking token, timelock, governor, registry, rewards, settlement, controllers, and example engines
- deploys VRF and poker verifier mocks
- grants required minting / settlement / controller / adapter roles
- registers both example engines in the registry
- seeds:
  - admin
  - player 1
  - player 2
  - solo creator
  - poker creator

### Run the deploy smoke

```bash
./script/e2e_deploy_smoke.sh
```

The smoke script:

- starts Anvil
- runs the local deploy script
- verifies deploy-time roles and registry state
- checks seeded balances
- performs one post-deploy staking interaction

## Testing Strategy

Scuro uses two layers of tests:

### Focused contract tests

These target specific protocol areas:

- `test/ProtocolCore.t.sol`
- `test/NumberPickerAdapter.t.sol`
- `test/TournamentController.t.sol`

### Layered E2E tests

These live under `test/e2e`.

- `SmokeE2E.t.sol`
  - protocol bootstrapping
  - role wiring
  - registry compatibility
  - one minimal happy path per major subsystem
- `UserFlowsE2E.t.sol`
  - full valid user journeys across solo, tournament, PvP, creator epoch, and governance flows
- `AbusePathsE2E.t.sol`
  - replay protection
  - unauthorized access
  - inactive engines
  - bad timing
  - invalid proofs
  - duplicate claims / settlements

The E2E completeness gate is documented in [test/e2e/MATRIX.md](./test/e2e/MATRIX.md).

## Coverage Philosophy

This repository currently treats scenario coverage as the primary quality gate.

Why:

- the codebase relies on `via_ir`
- disabling IR for coverage causes compiler failures (`stack too deep` / Yul issues)
- raw percentage coverage is therefore not the right short-term gate

Current rule:

- exhaustive flow coverage first
- coverage matrix tracked in `test/e2e/MATRIX.md`
- percentage gating can be revisited after the coverage toolchain is stable for this codebase

## Main Contracts

### Core

- `src/ScuroToken.sol`
- `src/ScuroStakingToken.sol`
- `src/ScuroGovernor.sol`
- `src/ProtocolSettlement.sol`
- `src/GameEngineRegistry.sol`
- `src/CreatorRewards.sol`

### Controllers

- `src/controllers/TournamentController.sol`
- `src/controllers/PvPController.sol`
- `src/controllers/NumberPickerAdapter.sol`

### Engines

- `src/engines/NumberPickerEngine.sol`
- `src/engines/SingleDraw2To7Engine.sol`

### Interfaces and helpers

- `src/interfaces/`
- `src/libraries/PokerZKStatements.sol`
- `src/mocks/`

## Example User Flows Covered Today

- player stakes SCU and gains voting power
- governance changes creator epoch duration
- player performs solo number-picker play
- creator accrues and claims rewards after epoch close
- tournament match settles through poker engine
- PvP session settles through poker engine
- inactive engine and replay protections block invalid settlement flows
- poker timeout, fold, tie, and verifier-rejection paths are exercised

## Notes

- The root package is the only supported build target.
- Archived directories are intentionally excluded from current testing and deployment.
- Generated artifacts live under `out/`, `cache/`, and `broadcast/` and are ignored by git where appropriate.

## Recommended Commands

```bash
# Build
forge build

# Full test suite
forge test --offline

# E2E only
forge test --match-path 'test/e2e/*.t.sol' --offline

# Deploy smoke
./script/e2e_deploy_smoke.sh
```
