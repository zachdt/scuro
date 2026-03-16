# DeveloperExpressionRegistry

## Purpose

`DeveloperExpressionRegistry` is the ERC721 attribution registry that links developer-owned expressions to engine types and expression hashes.

## Caller Model

- Developers mint expressions permissionlessly
- Moderators can toggle active state
- Settlement reads compatibility and ownership

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `MODERATOR_ROLE`

## Constructor And Config

- `constructor(admin)` initializes the ERC721 as `Scuro Developer Expression` / `SCUDEV`
- `nextExpressionId` starts at `1`

## Public API

- `mintExpression(engineType, expressionHash, metadataURI)`
- `setExpressionActive(expressionTokenId, active)`
- `getExpressionMetadata(expressionTokenId)`
- `isExpressionCompatible(engineType, expressionTokenId)`
- `supportsInterface(interfaceId)`

## Events

- `ExpressionMinted`
- `ExpressionActiveSet`

## State And Lifecycle Notes

- Compatibility requires both `active == true` and exact engine-type equality
- `originalMinter` is immutable metadata; reward ownership follows current NFT ownership instead

## Revert Conditions

- Zero engine type
- Zero expression hash
- Empty metadata URI
- Unknown expression id

## Test Anchors

- `test/DeveloperExpressionRegistry.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
