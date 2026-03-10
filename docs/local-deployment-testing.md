# Local Deployment And Testing

This guide covers the practical developer workflow for Scuro's local stack:

- validating committed zk artifacts
- running the contract and E2E suites
- deploying the full local stack to Anvil
- running the deploy smoke with real poker and blackjack proofs
- verifying developer rewards and expression registry behavior

## What Is In Scope

The active local stack includes three example engines:

- `NumberPickerEngine`: solo VRF-backed example
- `SingleDraw2To7Engine`: poker engine used by tournament and PvP controllers, backed by zk proofs
- `SingleDeckBlackjackEngine`: solo blackjack engine backed by zk proofs

It also includes the full developer rewards path:

- `GameEngineRegistry` for engine deployment metadata and `developerRewardBps`
- `DeveloperExpressionRegistry` for developer-owned engine expression NFTs
- `DeveloperRewards` for epoch-based SCU claims

## Prerequisites

- Foundry: `forge`, `cast`, `anvil`
- Bun
- `bash`

Use `--offline` with `forge test` in this environment. It avoids external lookup behavior that is not needed for local verification.

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

### 5. Run the focused contract tests

```bash
forge test --match-path 'test/DeveloperExpressionRegistry.t.sol' --offline
forge test --match-path 'test/TournamentController.t.sol' --offline
forge test --match-path 'test/BlackjackController.t.sol' --offline
forge test --match-path 'test/NumberPickerAdapter.t.sol' --offline
forge test --match-path 'test/ProtocolCore.t.sol' --offline
```

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

- token, staking, governor, timelock, engine registry, developer expression registry, developer rewards, and settlement
- `TournamentController`, `PvPController`, `NumberPickerAdapter`, and `BlackjackController`
- `NumberPickerEngine`, `SingleDraw2To7Engine`, and `SingleDeckBlackjackEngine`
- poker and blackjack Groth16 verifier bundles
- settlement/controller/adapter/engine roles
- example expression NFTs owned by the local solo and poker developer accounts
- seeded balances for admin, two players, and developer wallets

## Deploy Smoke

Run the full local smoke with:

```bash
./script/e2e_deploy_smoke.sh
```

The deploy smoke does all of the following:

- validates committed zk artifacts
- starts Anvil
- deploys the full stack
- verifies role wiring, registry registrations, and expression token ownership
- checks seeded balances
- performs a staking interaction
- executes one real-proof poker flow using a poker expression token
- executes one real-proof blackjack flow using a blackjack expression token

This is the highest-signal local verification command because it exercises both zk-backed engines and the developer rewards path against deployed contracts, not just against the in-test harnesses.

## Developer Rewards Verification

The local stack now expects every gameplay entrypoint to carry an `expressionTokenId`.

The controller entrypoints are:

- `NumberPickerAdapter.play(..., expressionTokenId)`
- `BlackjackController.startHand(..., expressionTokenId)`
- `TournamentController.createTournament(..., expressionTokenId)`
- `PvPController.createSession(..., expressionTokenId)`

For the multi-step controllers, that token ID is stored first and then reused later:

- blackjack settlement reads `sessionExpressionTokenId(sessionId)`
- tournament settlement reads `tournaments(tournamentId).expressionTokenId`
- PvP settlement reads `sessions(sessionId).expressionTokenId`

The important invariants are:

- the expression NFT engine type must match the registered engine type
- the expression NFT must be active
- the engine deployment must be active
- `developerRewardBps` comes from `GameEngineRegistry`
- the reward recipient is the current `ownerOf(expressionTokenId)` at settlement time
- for tournament, PvP, and blackjack flows, a mid-session expression transfer changes who receives accrual if settlement has not happened yet

When debugging reward attribution locally:

- inspect the engine metadata in `GameEngineRegistry`
- inspect token ownership and metadata in `DeveloperExpressionRegistry`
- inspect epoch accruals in `DeveloperRewards`
- confirm the controller stored the expected `expressionTokenId`
- remember that compatibility is enforced when settlement books accrual, so a later expression deactivation or a bad stored token ID will surface during settlement rather than at game creation

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

- bad proofs, replay guards, invalid wagers, inactive engines, inactive expressions, and unauthorized access:
  - `test/e2e/AbusePathsE2E.t.sol`

## Review Notes

- Poker game initialization is controller-gated so an arbitrary caller cannot pre-seed predictable game IDs and block tournament or PvP session creation.
- Engine deactivation now blocks both new game creation and developer reward settlement until the engine is reactivated.
- The zk-backed engines still depend on off-chain proof coordination. Current tests cover proof validation and some timeout paths, but there is still no coordinator-timeout recovery path if proof submission stalls.
