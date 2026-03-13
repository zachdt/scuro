# Scuro PR Review Guide

Use this guide when preparing or reviewing the Scuro fork-reset PR.

## Review Order

Review the branch in three layers:

1. Vendored `reth` import and relocation of the old Solidity stack to `reference/solidity`
2. Scuro overlay: `scuro-node`, Scuro config/chainspec crates, genesis, and active-runtime docs
3. Pre-PR hardening: focused CI, local verification targets, and reviewer/contributor docs

## Validation Checklist

Run the full local suite from the repository root:

```bash
make scuro-pr
```

That target currently runs:

- `rustup run nightly cargo fmt -p scuro-config -p scuro-chainspec -p scuro-node -p scuro-node-bin --check`
- `cargo clippy -p scuro-config -p scuro-chainspec -p scuro-node -p scuro-node-bin --all-targets --locked -- -D warnings`
- `cargo test --locked -p scuro-config -p scuro-chainspec -p scuro-node`
- `cargo run --locked --bin scuro-node -- node --chain scuro-dev --help`
- `cargo check --locked --workspace`
- `forge test --offline` in `reference/solidity`

## Merge Strategy

The PR should be landed with preserved commit boundaries:

- rebase onto the latest `main` before final PR refresh
- keep the vendored import isolated from Scuro-owned changes
- do not squash
- use GitHub `Rebase and merge` if available; otherwise use a standard merge commit with squash disabled

## Non-Goals for This PR

Keep the PR scoped to the fork reset and its reviewability. Explicitly leave these for follow-up work:

- native verifier and verification-key registry parity
- Scuro-specific RPC extensions
- any attempt to make `reference/solidity` the active runtime path again
