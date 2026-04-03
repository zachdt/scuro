# Session Specs Lane

This lane is the canonical source of truth for game rules, economics, settlement precedence, and intended session lifecycle behavior.

Use these pages when you need product-level gameplay semantics:

- [Blackjack](./blackjack.md)
- [NumberPicker](./number-picker.md)
- [Slot Machine](./slot-machine.md)
- [Super Baccarat](./super-baccarat.md)
- [Tournament Poker](./tournament-poker.md)
- [PvP Poker](./pvp-poker.md)
- [Chemin de Fer](./chemin-de-fer.md)

## Authority Split

- Session specs are canonical for game rules, economics, settlement precedence, and intended lifecycle behavior.
- Reference docs are canonical for contract, interface, event, and current implementation semantics.
- Playbooks are canonical for client transaction sequences and operational read flows.

When a session spec intentionally describes a future product state, it must say so explicitly and list the implementation deltas required to bring the codebase into alignment.
