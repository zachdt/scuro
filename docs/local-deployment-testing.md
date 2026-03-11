# Local Deployment and Testing

This guide serves as the technical companion to the [Protocol Architecture](./protocol-architecture.md), providing the workflows and commands necessary to build, deploy, and verify the Scuro protocol in a local environment.

Following this guide ensures you can rapidly iterate on game logic, ZK circuits, and protocol-level integrations while maintaining a high degree of confidence in the system's integrity.

---

## Technical Scope

The local stack includes a comprehensive set of example engines and protocol services:

### Gameplay Modules
- **`NumberPickerEngine`**: A low-latency, VRF-backed solo gaming example.
- **`SingleDraw2To7Engine`**: A ZK-proven poker engine used across tournament and PvP controllers.
- **`SingleDeckBlackjackEngine`**: A secure solo blackjack experience utilizing Groth16 proofs.

### Protocol Infrastructure
- **`GameCatalog`**: Manages global module authorization, lifecycle, and reward configurations.
- **`GameDeploymentFactory`**: Streamlines the registration of new controllers and engines.
- **`DeveloperExpressionRegistry`**: Handles the lifecycle and ownership of developer-attribution NFTs.
- **`DeveloperRewards`**: Automates the calculation and distribution of inflationary activity rewards.

> [!NOTE]
> The root package is the primary build target. Archived directories are maintained for reference only and are excluded from active workflows.

---

## Prerequisites

Ensure your environment is equipped with the following:
- **Foundry**: `forge`, `cast`, and `anvil` for EVM development.
- **Bun**: For managing ZK-related scripts and tasks.
- **Bash**: For running integration and smoke scripts.

> [!TIP]
> Use the `--offline` flag with `forge test` to bypass unnecessary external lookups and accelerate your local feedback loop.

---

## Action-Oriented Command Reference

### Build & Validate
Prepare the codebase and ensure ZK artifacts are consistent:
```bash
# Compile all smart contracts
forge build

# Verify checked-in ZK artifacts and fixtures
bun run --cwd zk check

# Rebuild ZK artifacts (only needed when circuit sources change)
bun run --cwd zk build
```

### Protocol Verification
Run the comprehensive test suite to ensure system-wide integrity:
```bash
# Execute the full test suite
forge test --offline

# Run ONLY the layered end-to-end scenarios
forge test --match-path 'test/e2e/*.t.sol' --offline

# Perform a targeted contract test
forge test --match-path 'test/ProtocolCore.t.sol' --offline
```

### Integration Smoke Test
The **highest-signal** verification pass. This script deploys the full stack to a local Anvil instance and executes real gameplay flows:
```bash
./script/e2e_deploy_smoke.sh
```

---

## Test Suite Deep Dive

Scuro utilizes a multi-layered testing strategy to balance speed and coverage.

### Focused Unit Tests
These tests target individual subsystems in isolation:
- **`ProtocolCore`**: Validates tokens, staking, governance, and the economics of settlement.
- **`DeveloperExpressions`**: Verifies permissionless minting, transfers, and moderation logic.
- **`Gameplay Controllers`**: Individual tests for `Tournament`, `Blackjack`, and `NumberPicker` orchestration.

### Layered End-to-End (E2E)
Located in `test/e2e/`, these act as the final completeness gate:
- **`SmokeE2E`**: Confirms basic wiring and one happy path for every major subsystem.
- **`UserFlowsE2E`**: Simulates complete user journeys, from staking to competitive play and reward claims.
- **`AbusePathsE2E`**: Rigorously tests the protocol's defenses against replay attacks, unauthorized access, and invalid proofs.

---

## Coverage Philosophy

Currently, Scuro prioritizes **exhaustive scenario coverage** over raw line-percentage metrics.

**The Rationale:**
- The codebase leverages `via_ir`, which can cause compiler limitations (e.g., "stack too deep") when traditional coverage instrumentation is applied.
- Comprehensive user-story mapping (maintained in the [E2E Scenario Matrix](../test/e2e/MATRIX.md)) provides a more accurate measure of protocol safety than simple line hits.

---

## Manual Deployment Workflow

For developers who need fine-grained control over the local environment:

1.  **Launch Anvil**:
    ```bash
    anvil
    ```
2.  **Deploy the Stack**:
    ```bash
    PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    forge script script/DeployLocal.s.sol:DeployLocal \
      --rpc-url http://127.0.0.1:8545 \
      --broadcast
    ```

The deployment script wires the entire ecosystem, including all controllers, engines, ZK verifiers, and example developer expressions with seeded balances.

---

## Developer Attribution & Rewards

Scuro enforces a robust attribution model for every gameplay interaction.

### Key Invariants
- **Engine Matching**: The Expression NFT's engine type must match the module's registered engine.
- **Live Status**: Both the module and the expression must be active for settlement to occur.
- **Dynamic Accrual**: Rewards are credited to the **current owner** of the Expression NFT at the exact moment of settlement.

### Debugging Tips
When verifying rewards locally:
- Inspect `GameCatalog` for module metadata and reward percentages.
- Check `DeveloperExpressionRegistry` for NFT ownership status.
- Monitor `DeveloperRewards` to see accruals accumulate across epochs.

---

## Strategic Review Notes

- **Access Gating**: Poker game initialization is strictly controller-gated to prevent predictable game ID seeding.
- **Graceful Retirement**: The protocol supports a tiered decommissioning process (`RETIRED` vs. `DISABLED`) to protect in-flight user funds.
- **Coordinator Resilience**: Current ZK engines rely on off-chain coordinators. While proof validation is robust, work is ongoing to implement automated timeouts and recovery paths for stalled submissions.
