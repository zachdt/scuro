# Integration Lane

This lane turns the reference docs into concrete client workflows for Node APIs, Rust APIs, relayers, and indexers.

Use the [session specs lane](../session-specs/README.md) for canonical rules and economics. Playbooks should focus on transaction order, read flows, and operational notes.

## Playbooks

- [Approvals and Staking](./token-and-staking.md)
- [Expression Lifecycle](./expression-lifecycle.md)
- [NumberPicker](./number-picker-playbook.md)
- [Slot Machine](./slot-machine-playbook.md)
- [Super Baccarat](./super-baccarat-playbook.md)
- [Tournament Poker](./tournament-poker-playbook.md)
- [PvP Poker](./pvp-poker-playbook.md)
- [Blackjack](./blackjack-playbook.md)
- [Chemin de Fer](./chemin-de-fer-playbook.md)
- [Governance](./governance-playbook.md)
- [Scenario Mapping](./scenario-mapping.md)

## Expected Client Capabilities

- Read deployment manifests and catalog metadata
- Encode transactions against the correct controller or engine
- Decode events and recover state from views
- Coordinate proof-bearing transitions for poker and blackjack
- Handle module lifecycle gates and timeout deadlines safely
