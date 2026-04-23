# Integration Lane

This lane turns the reference docs into concrete client workflows for Node APIs, Rust APIs, relayers, and indexers.

## Playbooks

- [Approvals and Staking](./token-and-staking.md)
- [Expression Lifecycle](./expression-lifecycle.md)
- [NumberPicker](./number-picker-playbook.md)
- [Slot Machine](./slot-machine-playbook.md)
- [Governance](./governance-playbook.md)
- [Scenario Mapping](./scenario-mapping.md)

## Expected Client Capabilities

- Read deployment manifests and catalog metadata
- Encode transactions against `NumberPickerAdapter` and `SlotMachineController`
- Decode events and recover state from views
- Handle module lifecycle gates safely
- Track expression ownership for developer reward attribution
