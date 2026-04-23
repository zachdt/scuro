# GameCatalog

## Purpose

`GameCatalog` is the source of truth for module identity, lifecycle status, engine type, config hash, and developer reward basis points.

## Caller Model

- Governance and deployment tooling write to the catalog
- Controllers, engines, and clients read from it for authorization and routing

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`: can update module status
- `REGISTRAR_ROLE`: can register modules

## Constructor And Config

- `constructor(admin)` grants both roles to `admin`
- `nextModuleId` starts at `1`

## Public API

- `registerModule(moduleData)`: inserts a new module and indexes it by controller and engine
- `setModuleStatus(moduleId, status)`: changes `LIVE`, `RETIRED`, or `DISABLED`
- `getModule(moduleId)`, `getModuleByController(controller)`, `getModuleByEngine(engine)`
- `isLaunchableController`, `isSettlableController`, `isLaunchableEngine`, `isSettlableEngine`
- `isAuthorizedControllerForEngine(controller, engine)`: the core controller/engine binding check

## Events

- `ModuleRegistered`
- `ModuleStatusUpdated`

## State And Lifecycle Notes

- `LIVE` modules can launch and settle
- `RETIRED` modules cannot launch but can still settle
- `DISABLED` modules can do neither
- `configHash` is stored but not interpreted on-chain; clients should treat it as compatibility metadata

## Revert Conditions

- Zero controller, zero engine, zero engine type
- Duplicate controller or engine registration
- Invalid `developerRewardBps`
- Unknown module or controller lookups

## Test Anchors

- `test/ProtocolCore.t.sol`
- `test/e2e/SmokeE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
