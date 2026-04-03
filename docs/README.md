# Scuro Documentation

This documentation set is organized for SDK authors first. The goal is that a Node or Rust API implementer can understand the protocol surface, derive stable client concepts, and consume generated metadata without reverse-engineering the Solidity source.

Start with the [root README](../README.md) for the product-level overview, then use the lanes below depending on the kind of work you are doing.

## Lanes

### Concepts

Use the concepts lane to understand the protocol model before touching code:

- [Concepts Index](./concepts/README.md)
- [Protocol Architecture](./protocol-architecture.md)
- [Game Module User Flows](./game-module-user-flows.md)
- [Canonical Terminology](./concepts/canonical-terminology.md)
- [Enum and Phase Mappings](./concepts/protocol-enums.md)
- [Event Indexing Guide](./concepts/event-indexing.md)
- [Deployment and Config Guide](./concepts/deployment-config.md)

### Session Specs

Use the session-spec lane when you need canonical game rules, economics, settlement precedence, or intended session lifecycle behavior:

- [Session Specs Index](./session-specs/README.md)
- [Blackjack Session Spec](./session-specs/blackjack.md)
- [NumberPicker Session Spec](./session-specs/number-picker.md)
- [Slot Machine Session Spec](./session-specs/slot-machine.md)
- [Super Baccarat Session Spec](./session-specs/super-baccarat.md)
- [Tournament Poker Session Spec](./session-specs/tournament-poker.md)
- [PvP Poker Session Spec](./session-specs/pvp-poker.md)
- [Chemin de Fer Session Spec](./session-specs/chemin-de-fer.md)

### Reference

Use the reference lane when you need exact contract, interface, event, and current implementation semantics:

- [Reference Index](./reference/README.md)
- [Core Services](./reference/protocol-settlement.md), [Game Catalog](./reference/game-catalog.md), [Deployment Factory](./reference/game-deployment-factory.md)
- [Economics](./reference/scuro-token.md), [Staking](./reference/scuro-staking-token.md), [Developer Rewards](./reference/developer-rewards.md), [Expression Registry](./reference/developer-expression-registry.md)
- [Controllers](./reference/number-picker-adapter.md), [Slot Machine Controller](./reference/slot-machine-controller.md), [Super Baccarat Controller](./reference/super-baccarat-controller.md), [Tournament Controller](./reference/tournament-controller.md), [PvP Controller](./reference/pvp-controller.md), [Blackjack Controller](./reference/blackjack-controller.md), [Chemin de Fer Controller](./reference/chemin-de-fer-controller.md)
- [Engines](./reference/number-picker-engine.md), [Slot Machine Engine](./reference/slot-machine-engine.md), [Super Baccarat Engine](./reference/super-baccarat-engine.md), [Single Draw 2-7](./reference/single-draw-2-7-engine.md), [Blackjack Engine](./reference/blackjack-engine.md), [Chemin de Fer Engine](./reference/chemin-de-fer-engine.md)
- [Verifier Bundles](./reference/poker-verifier-bundle.md), [Blackjack Verifier Bundle](./reference/blackjack-verifier-bundle.md)
- [Gameplay Interfaces](./reference/gameplay-interfaces.md), [Proof Interfaces](./reference/proof-interfaces.md)

### Integration

Use the integration lane when building clients, indexers, coordinators, or deployment automation:

- [Integration Index](./integration/README.md)
- [Approvals and Staking Playbook](./integration/token-and-staking.md)
- [Expression Lifecycle Playbook](./integration/expression-lifecycle.md)
- [NumberPicker Playbook](./integration/number-picker-playbook.md)
- [Slot Machine Playbook](./integration/slot-machine-playbook.md)
- [Super Baccarat Playbook](./integration/super-baccarat-playbook.md)
- [Tournament Poker Playbook](./integration/tournament-poker-playbook.md)
- [PvP Poker Playbook](./integration/pvp-poker-playbook.md)
- [Blackjack Playbook](./integration/blackjack-playbook.md)
- [Chemin de Fer Playbook](./integration/chemin-de-fer-playbook.md)
- [Governance Playbook](./integration/governance-playbook.md)
- [Scenario-to-Docs Mapping](./integration/scenario-mapping.md)

### Generated Metadata

Use generated metadata when bootstrapping Node or Rust APIs:

- [Generated Metadata Index](./generated/README.md)
- `docs/generated/protocol-manifest.json`
- `docs/generated/protocol-manifest.schema.json`
- `docs/generated/event-signatures.json`
- `docs/generated/enum-labels.json`
- `docs/generated/proof-inputs.json`

## Recommended Reading Order

1. [Protocol Architecture](./protocol-architecture.md)
2. [Game Module User Flows](./game-module-user-flows.md)
3. [Canonical Terminology](./concepts/canonical-terminology.md)
4. [Session Specs Index](./session-specs/README.md)
5. [Reference Index](./reference/README.md)
6. [Integration Index](./integration/README.md)
7. [Generated Metadata Index](./generated/README.md)
8. [Local Deployment & Testing](./local-deployment-testing.md)
9. [E2E Scenario Matrix](../test/e2e/MATRIX.md)
