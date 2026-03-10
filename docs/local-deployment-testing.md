# Local Deployment And Testing

This guide is the developer/operator companion to the root [README](../README.md). Use it when you need to build the repo, validate zk artifacts, choose the right test suite, deploy the local stack, or run the end-to-end smoke against Anvil.

Next step after this page: use the [E2E scenario matrix](../test/e2e/MATRIX.md) when you need to confirm that a user story or edge case is covered by the suite.

## Documentation Links

- [Docs index](./README.md)
- [Protocol architecture](./protocol-architecture.md)
- [E2E scenario matrix](../test/e2e/MATRIX.md)

## What Is In Scope

The active local stack includes three example engines:

- `NumberPickerEngine`: solo VRF-backed example
- `SingleDraw2To7Engine`: poker engine used by tournament and PvP controllers, backed by zk proofs
- `SingleDeckBlackjackEngine`: solo blackjack engine backed by zk proofs

It also includes the full developer-attribution path:

- `GameCatalog` for module metadata, controller/engine authorization, lifecycle status, and `developerRewardBps`
- `GameDeploymentFactory` for supported module deployment and registration
- `DeveloperExpressionRegistry` for developer-owned engine expression NFTs
- `DeveloperRewards` for epoch-based SCU claims

The root package is the only supported build target. Archived directories are reference-only and are intentionally excluded from current build, deployment, and test workflows.

## Prerequisites

- Foundry: `forge`, `cast`, `anvil`
- Bun
- `bash`

Use `--offline` with `forge test` in this environment. It avoids external lookup behavior that is not needed for local verification.

## Command Quick Reference

Build the contracts:

```bash
forge build
```

Validate committed zk artifacts:

```bash
bun run --cwd zk check
```

Rebuild zk artifacts only when circuit sources change:

```bash
bun run --cwd zk build
```

Run the full suite:

```bash
forge test --offline
```

Run the layered E2E suite only:

```bash
forge test --match-path 'test/e2e/*.t.sol' --offline
```

Run focused contract tests:

```bash
forge test --match-path 'test/DeveloperExpressionRegistry.t.sol' --offline
forge test --match-path 'test/TournamentController.t.sol' --offline
forge test --match-path 'test/BlackjackController.t.sol' --offline
forge test --match-path 'test/NumberPickerAdapter.t.sol' --offline
forge test --match-path 'test/ProtocolCore.t.sol' --offline
```

Run the deploy smoke:

```bash
./script/e2e_deploy_smoke.sh
```

## Recommended Order

### 1. Validate committed zk artifacts

Run this when you want to confirm the checked-in verifier inputs and fixtures are internally consistent:

```bash
bun run --cwd zk check
```

Use this instead of rebuilding circuits for normal contract work.

### 2. Rebuild zk artifacts only when circuit sources change

Run this only if files under `zk/circuits/`, verifier generation, or fixture generation changed:

```bash
bun run --cwd zk build
```

### 3. Run the full test suite

```bash
forge test --offline
```

### 4. Run only the layered end-to-end suite

```bash
forge test --match-path 'test/e2e/*.t.sol' --offline
```

### 5. Run focused controller and protocol tests

```bash
forge test --match-path 'test/DeveloperExpressionRegistry.t.sol' --offline
forge test --match-path 'test/TournamentController.t.sol' --offline
forge test --match-path 'test/BlackjackController.t.sol' --offline
forge test --match-path 'test/NumberPickerAdapter.t.sol' --offline
forge test --match-path 'test/ProtocolCore.t.sol' --offline
```

## Test Suite Breakdown

### Focused contract tests

These cover protocol subsystems in isolation:

- `test/ProtocolCore.t.sol`: token, staking, governance, settlement, and developer reward expectations
- `test/DeveloperExpressionRegistry.t.sol`: permissionless expression mint, transfer, and moderation behavior
- `test/NumberPickerAdapter.t.sol`: solo adapter flow, payout, and developer accrual
- `test/TournamentController.t.sol`: tournament orchestration on top of the poker engine
- `test/BlackjackController.t.sol`: blackjack session lifecycle and settlement behavior

### Layered E2E tests

These live under `test/e2e` and act as the scenario-completeness gate:

- `SmokeE2E.t.sol`: full-stack wiring, catalog setup, controller-engine authorization, expression wiring, and one minimal happy path per major subsystem
- `UserFlowsE2E.t.sol`: end-to-end user journeys across solo play, tournament play, PvP play, developer rewards, and governance
- `AbusePathsE2E.t.sol`: replay protection, unauthorized access, retired or disabled modules, inactive expressions, timing issues, and invalid proof or settlement paths

The detailed coverage matrix is maintained in [test/e2e/MATRIX.md](../test/e2e/MATRIX.md).

## Coverage Philosophy

Scenario coverage is currently the primary quality gate for this repository.

Why:

- the codebase relies on `via_ir`
- disabling IR for coverage causes compiler failures such as `stack too deep` and Yul issues
- raw percentage coverage is therefore not the right short-term gate

Current rule:

- prioritize exhaustive flow coverage first
- keep the completeness gate in [test/e2e/MATRIX.md](../test/e2e/MATRIX.md)
- revisit percentage-based gating after the coverage toolchain is stable for this codebase

## Manual Local Deployment

Start Anvil in one terminal:

```bash
anvil
```

Deploy from another terminal:

```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
forge script script/DeployLocal.s.sol:DeployLocal \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

The local deploy script wires:

- token, staking, governor, timelock, game catalog, game deployment factory, developer expression registry, developer rewards, and settlement
- `TournamentController`, `PvPController`, `NumberPickerAdapter`, and `BlackjackController`
- one `NumberPickerEngine`, two `SingleDraw2To7Engine` module instances (tournament and PvP), and one `SingleDeckBlackjackEngine`
- poker and blackjack Groth16 verifier bundles
- catalog and factory governance roles plus module registration
- example expression NFTs owned by the local solo and poker developer accounts
- seeded balances for admin, two players, and developer wallets

Current branch note:

- `script/DeployLocal.s.sol` and `./script/e2e_deploy_smoke.sh` target the new catalog/factory flow, but local broadcast currently fails when `forge script --broadcast` tries to deploy `GameDeploymentFactory`.
- The contract's creation bytecode exceeds the EVM initcode limit, so the smoke path is not yet a passing pre-commit gate on this branch even though the test suites pass.

## Deploy Smoke

Run the full local smoke with:

```bash
./script/e2e_deploy_smoke.sh
```

The smoke script performs the highest-signal local verification pass because it exercises the deployed contracts, not just the test harnesses. It does all of the following:

- validates committed zk artifacts
- starts Anvil
- deploys the full stack
- verifies catalog/controller wiring, module registration metadata, and expression token ownership
- checks seeded balances
- performs a staking interaction
- executes one real-proof poker flow using a poker expression token
- executes one real-proof blackjack flow using a blackjack expression token

## Developer Attribution Verification

The local stack expects every gameplay entrypoint to carry an `expressionTokenId`.

The main controller entrypoints are:

- `NumberPickerAdapter.play(..., expressionTokenId)`
- `BlackjackController.startHand(..., expressionTokenId)`
- `TournamentController.createTournament(entryFee, rewardPool, startingStack, expressionTokenId)`
- `PvPController.createSession(player1, player2, stake, rewardPool, startingStack, expressionTokenId)`

For multi-step flows, controllers persist the token ID and settlement reuses it later:

- blackjack: `sessionExpressionTokenId(sessionId)`
- tournament: `tournaments(tournamentId).expressionTokenId`
- PvP: `sessions(sessionId).expressionTokenId`

The important invariants are:

- the expression NFT engine type must match the registered engine type
- the expression NFT must be active
- the module must be settlable in `GameCatalog`
- `developerRewardBps` comes from the module metadata stored in `GameCatalog`
- the reward recipient is the current `ownerOf(expressionTokenId)` at settlement time
- for tournament, PvP, and blackjack flows, a mid-session expression transfer changes who receives accrual if settlement has not happened yet

When debugging attribution locally:

- inspect module metadata in `GameCatalog`
- inspect token ownership and metadata in `DeveloperExpressionRegistry`
- inspect epoch accruals in `DeveloperRewards`
- confirm the controller stored the expected `expressionTokenId`
- remember that compatibility is enforced when settlement books accrual, so a later expression deactivation or module status change can surface during settlement rather than at session creation

## User Story To Test Mapping

### Governance and token stories

- stake SCU and gain voting power:
  - `test/ProtocolCore.t.sol`
  - `test/e2e/SmokeE2E.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`
- governance updates developer reward timing:
  - `test/ProtocolCore.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`

### Developer rewards stories

- permissionless expression mint, transfer, and deactivation:
  - `test/DeveloperExpressionRegistry.t.sol`
- number picker play, payout, and developer accrual:
  - `test/NumberPickerAdapter.t.sol`
  - `test/e2e/SmokeE2E.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`
- transferred expression NFT redirects later-booked accrual in the covered immediate-settlement flow:
  - `test/ProtocolCore.t.sol`
  - `test/NumberPickerAdapter.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`

### Competitive play stories

- poker tournament lifecycle:
  - `test/TournamentController.t.sol`
  - `test/e2e/SmokeE2E.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`
- poker PvP lifecycle:
  - `test/e2e/SmokeE2E.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`
- blackjack session lifecycle with real proofs:
  - `test/BlackjackController.t.sol`
  - `script/e2e_deploy_smoke.sh`

### Abuse and negative-path stories

- bad proofs, replay guards, invalid wagers, retired or disabled modules, inactive expressions, and unauthorized access:
  - `test/e2e/AbusePathsE2E.t.sol`

## Review Notes

- Poker game initialization is controller-gated so an arbitrary caller cannot pre-seed predictable game IDs and block tournament or PvP session creation.
- Module retirement now blocks new game creation while preserving settlement paths for in-flight games; module disablement blocks both launch and settlement.
- `GameDeploymentFactory` is currently too large to broadcast through `forge script --broadcast` on Anvil because its creation bytecode exceeds the initcode limit.
- The zk-backed engines still depend on off-chain proof coordination. Current tests cover proof validation and some timeout paths, but there is still no coordinator-timeout recovery path if proof submission stalls.

Next step: consult the [E2E scenario matrix](../test/e2e/MATRIX.md) to map a user story or regression risk to a concrete scenario ID and test name.
