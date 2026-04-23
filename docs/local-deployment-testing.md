# Local Deployment And Testing

Local development targets the canonical core, `NumberPicker`, and `SlotMachine`.

## Build And Test

```bash
forge build --offline
forge test --offline
forge test --match-path 'test/invariants/*.t.sol' --offline
```

Focused lanes:

- `test/ProtocolCore.t.sol`
- `test/NumberPickerAdapter.t.sol`
- `test/SlotMachineController.t.sol`
- `test/e2e/*.t.sol`
- `test/invariants/SlotMachineInvariants.t.sol`

## Local Deployment

```bash
forge script script/DeployLocal.s.sol:DeployLocal --broadcast --rpc-url http://127.0.0.1:8545
```

The local deploy wires:

- Core token, staking, governance, catalog, settlement, expression, and rewards contracts
- Number-picker controller and engine
- Slot controller and engine
- Canonical slot presets: `base`, `free`, `pick`, `hold`
- Seed actors and expression token ids for local smokes

## Smoke Checks

```bash
./script/e2e_deploy_smoke.sh
bash script/aws/verify_local.sh
```

AWS-style smoke targets:

```bash
bash script/aws/smoke.sh number-picker
bash script/aws/smoke.sh slot
```

## Generated Metadata

```bash
bash script/docs/check_sdk_docs.sh
```

This regenerates the protocol manifest, event signatures, enum labels, and ABI files from the current Foundry build.
