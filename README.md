# Scuro

Scuro is now structured as an in-repo fork of `reth`, pinned to upstream `v1.11.3` (`d6324d63e27ef6b7c49cdc9b1977c1b808234c7b`). The active runtime is a Rust-first EVM-fork L1, while the previous Solidity/Foundry protocol implementation is preserved under [`reference/solidity`](./reference/solidity) as behavioral reference only.

## Active Layout

- `bin/scuro-node`: Scuro-first node entrypoint.
- `crates/scuro/config`: Scuro-native protocol config seam.
- `crates/scuro/chainspec`: Scuro devnet chain spec and CLI parser.
- `crates/scuro/node`: Scuro launcher and reserved protocol hooks.
- `reference/solidity`: Previous contract implementation, tests, docs, and ZK assets kept for porting reference.

## Current Milestone

The repository currently targets the first `reth`-fork milestone:

- `scuro-node` boots a local Scuro devnet on chain id `31338`.
- Standard EVM execution remains intact.
- Native verifier and verification-key registry behavior are not implemented yet; the Scuro hook layer only reserves the integration seam for the next milestone.

## Quickstart

```bash
cargo run --bin scuro-node -- node --chain scuro-dev --http
```

`--dev` also resolves to the Scuro dev chain.

## Docs

- [`docs/scuro-fork.md`](./docs/scuro-fork.md): Scuro fork overview and runtime layout.
- [`docs/scuro-pr-review.md`](./docs/scuro-pr-review.md): PR review order, validation checklist, and merge strategy.
- [`docs/README.md`](./docs/README.md): Upstream contributor docs plus Scuro-specific additions.
- [`etc/scuro-upstream.toml`](./etc/scuro-upstream.toml): Exact upstream pin and reference paths.

## Pre-PR Verification

Use the Scuro-specific verification target before opening or refreshing a PR:

```bash
make scuro-pr
```

This runs the focused Scuro lint/test suite, a full workspace `cargo check`, a CLI smoke check for
the documented `scuro-node` command, and the reference Solidity suite via `forge test --offline`.

## Reference Solidity Stack

The Solidity implementation is no longer the active runtime, but it is still preserved for:

- protocol behavior reference
- test fixture reference
- future native-port parity work

See [`reference/solidity/README.md`](./reference/solidity/README.md) for the original contract-oriented overview.

> **Note**
>
> Some tests use random number generators to generate test data. If you want to use a deterministic seed, you can set the `SEED` environment variable.

## Getting Help

If you have any questions, first see if the answer to your question can be found in the [docs][book].

If the answer is not there:

- Join the [Telegram][tg-url] to get help, or
- Open a [discussion](https://github.com/paradigmxyz/reth/discussions/new) with your question, or
- Open an issue with [the bug](https://github.com/paradigmxyz/reth/issues/new?assignees=&labels=C-bug%2CS-needs-triage&projects=&template=bug.yml)

## Security

See [`SECURITY.md`](./SECURITY.md).

## Acknowledgements

Reth is a new implementation of the Ethereum protocol. In the process of developing the node we investigated the design decisions other nodes have made to understand what is done well, what is not, and where we can improve the status quo.

None of this would have been possible without them, so big shoutout to the teams below:

- [Geth](https://github.com/ethereum/go-ethereum/): We would like to express our heartfelt gratitude to the go-ethereum team for their outstanding contributions to Ethereum over the years. Their tireless efforts and dedication have helped to shape the Ethereum ecosystem and make it the vibrant and innovative community it is today. Thank you for your hard work and commitment to the project.
- [Erigon](https://github.com/ledgerwatch/erigon) (fka Turbo-Geth): Erigon pioneered the ["Staged Sync" architecture](https://erigon.substack.com/p/erigon-stage-sync-and-control-flows) that Reth is using, as well as [introduced MDBX](https://github.com/ledgerwatch/erigon/wiki/Choice-of-storage-engine) as the database of choice. We thank Erigon for pushing the state of the art research on the performance limits of Ethereum nodes.
- [Akula](https://github.com/akula-bft/akula/): Reth uses forks of the Apache versions of Akula's [MDBX Bindings](https://github.com/paradigmxyz/reth/pull/132), [FastRLP](https://github.com/paradigmxyz/reth/pull/63) and [ECIES](https://github.com/paradigmxyz/reth/pull/80). Given that these packages were already released under the Apache License, and they implement standardized solutions, we decided not to reimplement them to iterate faster. We thank the Akula team for their contributions to the Rust Ethereum ecosystem and for publishing these packages.

## Warning

The `NippyJar` and `Compact` encoding formats and their implementations are designed for storing and retrieving data internally. They are not hardened to safely read potentially malicious data.

[book]: https://reth.rs/
[tg-url]: https://t.me/paradigm_reth
