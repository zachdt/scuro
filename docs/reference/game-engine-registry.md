# GameEngineRegistry

## Purpose

`GameEngineRegistry` is an alternate engine-centric registry that stores engine metadata and capability flags. It is currently not the primary launch/settlement gate, but it remains part of the protocol surface.

## Caller Model

- Governance or admin tooling writes metadata
- Clients may read capability flags and developer reward config

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `REGISTRAR_ROLE`

## Constructor And Config

- `constructor(admin)` grants both roles to `admin`

## Public API

- `registerEngine(engine, metadata)`
- `setEngineActive(engine, active)`
- `getEngineMetadata(engine)`
- `isActive(engine)`
- `isRegisteredForTournament(engine)`
- `isRegisteredForPvP(engine)`
- `isRegisteredForSolo(engine)`
- `getDeveloperRewardConfig(engine)`

## Events

- `EngineRegistered`
- `EngineDeactivated`

## State And Lifecycle Notes

- Engines must start active
- Capability flags are explicit booleans, not derived from engine type

## Revert Conditions

- Zero engine address
- Zero engine type
- Invalid `developerRewardBps`
- Unknown engine on update or guarded reads

## Test Anchors

- Not currently covered by the shipped E2E matrix; treat as a documented but secondary surface
