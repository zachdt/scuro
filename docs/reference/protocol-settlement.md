# ProtocolSettlement

## Purpose

`ProtocolSettlement` is the only contract that moves SCU value for gameplay. Controllers call it to burn wagers, mint rewards, and book developer accruals.

## Caller Model

- Direct callers: authorized controllers only
- Downstream dependencies: `ScuroToken`, `DeveloperRewards`, `DeveloperExpressionRegistry`, `GameCatalog`

## Roles And Permissions

- No local access-control roles
- Authorization is entirely delegated to `GameCatalog.isSettlableController(msg.sender)`

## Constructor And Config

- `constructor(tokenAddress, catalogAddress, expressionRegistryAddress, developerRewardsAddress)`
- Immutable dependencies are exposed through `token()`, `developerRewards()`, `expressionRegistry()`, and `catalog()`

## Public API

- `token()`: returns the SCU token contract
- `developerRewards()`: returns the rewards contract
- `expressionRegistry()`: returns the expression registry
- `catalog()`: returns the catalog
- `burnPlayerWager(player, amount)`: burns approved SCU from `player`
- `mintPlayerReward(player, amount)`: mints SCU to `player`, no-op when `amount == 0`
- `accrueDeveloperForExpression(expressionTokenId, activityAmount)`: validates expression compatibility, computes accrual from module `developerRewardBps`, and records it in `DeveloperRewards`

## Events

- `PlayerWagerBurned`
- `PlayerRewardMinted`
- `DeveloperAccrualRecorded`

## State And Lifecycle Notes

- Settlement is allowed for `LIVE` and `RETIRED` modules because it keys off `isSettlableController`
- Expression compatibility is checked at settlement time, not launch time
- The reward recipient is the current owner of the expression NFT at settlement time

## Revert Conditions

- Unauthorized controller
- Inactive expression
- Expression engine type mismatch

## Test Anchors

- `test/ProtocolCore.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
