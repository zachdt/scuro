# Scuro `reth` Fork

Scuro is now centered on an in-repo fork of `reth`, pinned to `v1.11.3` (`d6324d63e27ef6b7c49cdc9b1977c1b808234c7b`).

## Layout

- `bin/scuro-node`: Scuro-first node entrypoint.
- `crates/scuro/config`: Scuro-native protocol configuration seam.
- `crates/scuro/chainspec`: Scuro chain spec defaults and CLI parser.
- `crates/scuro/node`: Scuro launcher and reserved protocol hooks for future native verifier work.
- `reference/solidity`: The previous Solidity/Foundry implementation, retained as a behavioral reference only.

## Current Milestone

The current fork milestone is intentionally narrow:

- `scuro-node` boots a local Scuro devnet on chain id `31338`.
- The runtime remains standard EVM execution.
- Native verifier and verification-key registry behavior are not implemented yet; the Scuro hook/config layer only reserves the integration seam.

## Running

```bash
cargo run --bin scuro-node -- node --chain scuro-dev --http
```

`--dev` also resolves to the Scuro dev chain.

## Validation

Run the focused pre-PR verification suite from the repository root:

```bash
make scuro-pr
```

That command is mirrored by the dedicated `scuro` GitHub Actions workflow and covers:

- Scuro-owned linting and formatting checks
- Rust tests for `scuro-config`, `scuro-chainspec`, and `scuro-node`
- A full workspace `cargo check`
- A CLI smoke check for the documented `scuro-node` invocation
- The reference Solidity suite under `reference/solidity` with `forge test --offline`

## Review and Merge

Use [`docs/scuro-pr-review.md`](./scuro-pr-review.md) as the PR review guide. The intended merge
shape is:

- preserve the vendored `reth` import boundary
- keep the Scuro overlay and pre-PR hardening work reviewable as separate layers
- merge without squashing

## Non-Goals

This milestone does not include:

- native verifier or verifier-registry parity
- Scuro-specific RPC namespaces
- reintroducing the old geth precompile runtime path into the active root
