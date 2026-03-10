# Local Deployment And Testing

This guide covers the practical developer workflow for Scuro's local stack:

- validating committed zk artifacts
- running the contract and E2E suites
- deploying the full local stack to Anvil
- running the deploy smoke with real poker and blackjack proofs

## What Is In Scope

The active local stack includes three example engines:

- `NumberPickerEngine`: solo VRF-backed example
- `SingleDraw2To7Engine`: poker engine used by tournament and PvP controllers, backed by zk proofs
- `SingleDeckBlackjackEngine`: solo blackjack engine backed by zk proofs

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

### 5. Run the focused controller tests

```bash
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

- token, staking, governor, timelock, registry, creator rewards, and settlement
- `TournamentController`, `PvPController`, `NumberPickerAdapter`, and `BlackjackController`
- `NumberPickerEngine`, `SingleDraw2To7Engine`, and `SingleDeckBlackjackEngine`
- poker and blackjack Groth16 verifier bundles
- settlement/controller/adapter/engine roles
- seeded balances for admin, two players, and engine creators

## Deploy Smoke

Run the full local smoke with:

```bash
./script/e2e_deploy_smoke.sh
```

The deploy smoke does all of the following:

- validates committed zk artifacts
- starts Anvil
- deploys the full stack
- verifies role wiring and registry registrations
- checks seeded balances
- performs a staking interaction
- executes one real-proof poker flow
- executes one real-proof blackjack flow

This is the highest-signal local verification command because it exercises both zk-backed engines against the deployed contracts, not just against the in-test harnesses.

## User Story To Test Mapping

### Governance and token stories

- stake SCU and gain voting power:
  - `test/ProtocolCore.t.sol`
  - `test/e2e/SmokeE2E.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`
- governance updates creator reward timing:
  - `test/ProtocolCore.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`

### Solo play stories

- number picker play, payout, and creator accrual:
  - `test/NumberPickerAdapter.t.sol`
  - `test/e2e/SmokeE2E.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`
- blackjack session lifecycle with real proofs:
  - `test/BlackjackController.t.sol`
  - `script/e2e_deploy_smoke.sh`

### Competitive play stories

- poker tournament lifecycle:
  - `test/TournamentController.t.sol`
  - `test/e2e/SmokeE2E.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`
- poker PvP lifecycle:
  - `test/e2e/SmokeE2E.t.sol`
  - `test/e2e/UserFlowsE2E.t.sol`

### Abuse and negative-path stories

- bad proofs, replay guards, invalid wagers, inactive engines, and unauthorized access:
  - `test/e2e/AbusePathsE2E.t.sol`

## Review Notes

- Poker game initialization is now controller-gated so an arbitrary caller cannot pre-seed predictable game IDs and block tournament or PvP session creation.
- Tournament engine deactivation now blocks new tournament games while still allowing already-started games to settle.
- The zk-backed engines still depend on off-chain proof coordination. Current tests cover proof validation and some timeout paths, but there is still no coordinator-timeout recovery path if proof submission stalls.
