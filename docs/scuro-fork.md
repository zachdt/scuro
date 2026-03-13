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
