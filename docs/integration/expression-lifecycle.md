# Expression Lifecycle Playbook

## Purpose

This flow defines how SDKs should create, cache, validate, and display developer attribution data.

## Sequence

1. Read the engine type for the target module from `GameCatalog`.
2. Call `mintExpression(engineType, expressionHash, metadataURI)` on `DeveloperExpressionRegistry`.
3. Cache `expressionTokenId`, `engineType`, `expressionHash`, `originalMinter`, owner, and `active`.
4. Before submitting any controller action that references an expression token, optionally preflight with `isExpressionCompatible(engineType, expressionTokenId)`.
5. During settlement or indexing, rely on the registry owner at the time of settlement as the reward recipient.

## Reads And Events

- `ExpressionMinted` is the primary creation event.
- `ExpressionActiveSet` changes moderation state.
- `ownerOf` and `getExpressionMetadata` together define the current attribution target.

## Failure Cases

- Zero `engineType`, zero `expressionHash`, or empty `metadataURI` revert on mint.
- Inactive or mismatched expressions cause settlement reverts in `ProtocolSettlement`.

## Relevant References

- [DeveloperExpressionRegistry](../reference/developer-expression-registry.md)
- [ProtocolSettlement](../reference/protocol-settlement.md)
- [GameCatalog](../reference/game-catalog.md)
