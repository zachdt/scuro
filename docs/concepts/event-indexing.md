# Event Indexing

Indexers should start from `docs/generated/protocol-manifest.json`, then subscribe to core, controller, engine, token, and rewards events.

## Primary Keys

- `module_id`
- `request_id`
- `spin_id`
- `preset_id`
- `expression_token_id`
- `epoch`

## Core Events

- `ModuleRegistered` and `ModuleStatusUpdated`: track controller, engine, engine type, config hash, reward rate, and lifecycle status.
- Settlement events: track wager burns, payouts, and reward accruals.
- Expression events: track active expression metadata and ERC721 ownership changes.
- Reward events: track epoch close and claim state.

## Gameplay Events

- NumberPicker: request, randomness callback, completion, and controller finalization.
- SlotMachine: `PresetRegistered`, `PresetActiveSet`, `SpinRequested`, feature-resolution events, `SpinResolved`, and `SpinFinalized`.

Always combine controller events with engine events. Engines describe gameplay state; controllers describe economic completion.
