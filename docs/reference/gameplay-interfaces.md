# Gameplay Interfaces

The canonical gameplay interface surface is intentionally small.

## `IScuroGameEngine`

Shared engine identity interface.

- `engineType()`

## `ISoloLifecycleEngine`

Settlement interface consumed by solo controllers.

- `engineType()`
- `getSettlementOutcome(requestId)`

`NumberPickerEngine` and `SlotMachineEngine` implement this lifecycle so controllers can finalize through the shared settlement path.
