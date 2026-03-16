# Concepts Lane

This lane defines the vocabulary and protocol rules that Node and Rust clients should share across implementations.

## Core Guides

- [Protocol Architecture](../protocol-architecture.md): Layer map, value flow, and contract relationships.
- [Game Module User Flows](../game-module-user-flows.md): Current runtime call sequences for every shipped module.
- [Canonical Terminology](./canonical-terminology.md): Stable cross-language names for protocol concepts.
- [Enum and Phase Mappings](./protocol-enums.md): Explicit numeric mappings that clients should encode instead of inferring.
- [Event Indexing Guide](./event-indexing.md): How to reconstruct state from logs plus fallback reads.
- [Deployment and Config Guide](./deployment-config.md): How clients should ingest deployment outputs and module metadata.

## What Belongs Here

- Shared nouns and lifecycle rules
- Cross-contract invariants
- Event-driven indexing models
- Deployment manifests and config shapes

## What Does Not Belong Here

- Method-by-method ABI detail: use [reference](../reference/README.md)
- End-to-end client transaction sequences: use [integration](../integration/README.md)
- Machine-readable artifacts: use [generated](../generated/README.md)
