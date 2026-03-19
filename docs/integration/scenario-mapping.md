# Scenario Mapping

This document maps the E2E scenario matrix to the new docs so coverage checks can verify that every scenario is explained somewhere outside the tests.

| Scenario ID | Docs anchor |
| --- | --- |
| `SMOKE-BOOTSTRAP` | `deployment-config`, `protocol-settlement`, `game-catalog` |
| `SMOKE-GOV` | `governance-playbook`, `scuro-governor`, `scuro-staking-token` |
| `SMOKE-SOLO` | `number-picker-playbook`, `number-picker-adapter`, `number-picker-engine` |
| `SMOKE-SLOT` | `slot-machine-playbook`, `slot-machine-controller`, `slot-machine-engine` |
| `SMOKE-TOURNAMENT` | `tournament-poker-playbook`, `tournament-controller`, `single-draw-2-7-engine` |
| `SMOKE-PVP` | `pvp-poker-playbook`, `pvp-controller`, `single-draw-2-7-engine` |
| `FLOW-SOLO-END2END` | `number-picker-playbook`, `developer-rewards`, `expression-lifecycle` |
| `FLOW-SOLO-MULTI` | `number-picker-playbook`, `developer-rewards` |
| `FLOW-EXPR-TRANSFER` | `expression-lifecycle`, `protocol-settlement` |
| `FLOW-SLOT-END2END` | `slot-machine-playbook`, `developer-rewards`, `expression-lifecycle` |
| `FLOW-SLOT-EXPR-TRANSFER` | `slot-machine-playbook`, `expression-lifecycle`, `protocol-settlement` |
| `FLOW-TOURNAMENT-END2END` | `tournament-poker-playbook`, `tournament-controller` |
| `FLOW-PVP-END2END` | `pvp-poker-playbook`, `pvp-controller` |
| `FLOW-GOV-CONFIG` | `governance-playbook`, `developer-rewards`, `scuro-governor` |
| `FLOW-MULTI-EPOCH` | `developer-rewards`, `event-indexing` |
| `ABUSE-SOLO-INPUTS` | `number-picker-engine`, `number-picker-adapter` |
| `ABUSE-SOLO-PENDING` | `number-picker-playbook`, `game-catalog` |
| `ABUSE-SLOT-PENDING` | `slot-machine-playbook`, `game-catalog`, `slot-machine-controller`, `slot-machine-engine` |
| `ABUSE-SETTLEMENT-LIFECYCLE` | `game-catalog`, `protocol-settlement`, `tournament-controller`, `pvp-controller` |
| `ABUSE-DEVELOPER-EPOCHS` | `developer-rewards` |
| `ABUSE-GOV` | `governance-playbook`, `scuro-governor` |
| `ABUSE-POKER` | `single-draw-2-7-engine`, `tournament-poker-playbook`, `pvp-poker-playbook` |
| `ABUSE-POKER-INIT` | `single-draw-2-7-engine`, `game-catalog` |
| `ABUSE-ROLES` | `protocol-settlement`, `game-catalog`, `game-deployment-factory` |
| `ABUSE-EXPRESSIONS` | `expression-lifecycle`, `developer-expression-registry`, `protocol-settlement` |
