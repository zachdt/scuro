# Game Module User Flows

Scuro currently ships two canonical solo modules.

| Module | Controller | Engine | Randomness | Canonical config |
| --- | --- | --- | --- | --- |
| NumberPicker | `NumberPickerAdapter` | `NumberPickerEngine` | VRF coordinator | `number-picker-auto` |
| SlotMachine | `SlotMachineController` | `SlotMachineEngine` | VRF coordinator | `base`, `free`, `pick`, `hold` presets |

## NumberPicker

```mermaid
sequenceDiagram
    participant Player
    participant Controller as NumberPickerAdapter
    participant Engine as NumberPickerEngine
    participant Settlement as ProtocolSettlement
    participant Rewards as DeveloperRewards

    Player->>Controller: play(wager, pick, playRef, expressionTokenId)
    Controller->>Settlement: burnPlayerWager
    Controller->>Engine: requestPlay
    Engine-->>Controller: callback resolves request
    Controller->>Settlement: mint payout and accrue rewards
    Settlement->>Rewards: book developer activity
```

## SlotMachine

```mermaid
sequenceDiagram
    participant Player
    participant Controller as SlotMachineController
    participant Engine as SlotMachineEngine
    participant Settlement as ProtocolSettlement
    participant Rewards as DeveloperRewards

    Player->>Controller: spin(wager, presetId, playRef, expressionTokenId)
    Controller->>Settlement: burnPlayerWager
    Controller->>Engine: requestSpin
    Engine-->>Engine: resolve base grid and bounded features
    Controller->>Settlement: mint payout and accrue rewards
    Settlement->>Rewards: book developer activity
```

## Lifecycle

- `LIVE`: starts and settlement are allowed.
- `RETIRED`: new starts are blocked; in-flight settlement remains allowed.
- `DISABLED`: starts and settlement are blocked.
