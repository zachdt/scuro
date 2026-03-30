# GameEngineRegistry

## Status

`GameEngineRegistry` is deprecated and is not part of the canonical beta release surface.

SDK, frontend, and indexer integrations should not depend on it for discovery, settlement authorization, or release manifests.

## Replacement Surfaces

- Use `GameCatalog` as the canonical registry for deployed controller/engine/verifier bundles, lifecycle status, and reward-bps metadata.
- Use `DeveloperExpressionRegistry` for expression compatibility keyed by `engineType`.
- Use the beta release `manifest.json` and `actors.json` as the published integration handoff for deployed addresses.

## Why It Was Deprecated

- The live protocol path does not read from `GameEngineRegistry`.
- `GameCatalog` already stores the engine-centric metadata the runtime actually uses.
- Keeping both registries active creates overlapping sources of truth for engine metadata.

## Migration Guidance

- Prefer `GameCatalog.getModuleByEngine(engine)` for verifier, config hash, module status, and reward-bps reads.
- Prefer `GameCatalog.isLaunchableEngine(engine)` and `GameCatalog.isSettlableEngine(engine)` for lifecycle gating.
- Prefer `DeveloperExpressionRegistry.isExpressionCompatible(engineType, expressionTokenId)` for expression compatibility checks.
