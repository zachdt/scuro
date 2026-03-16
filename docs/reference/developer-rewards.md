# DeveloperRewards

## Purpose

`DeveloperRewards` tracks per-epoch developer accrual and mints SCU when closed epochs are claimed.

## Caller Model

- `ProtocolSettlement` accrues rewards
- Governance or timelock manages epoch duration and closes epochs
- Developers claim closed epochs directly

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `SETTLEMENT_ROLE`
- `EPOCH_MANAGER_ROLE`

## Constructor And Config

- `constructor(admin, tokenAddress, epochDurationSeconds)`
- `currentEpoch` starts at `1`
- `epochStart` is initialized to deployment `block.timestamp`

## Public API

- `token()`
- `setEpochDuration(newDuration)`
- `accrue(developer, amount)`
- `closeCurrentEpoch()`
- `claim(epochs)`

## Events

- `DeveloperAccrued`
- `EpochClosed`
- `DeveloperClaimed`

## State And Lifecycle Notes

- Zero-address or zero-amount accrual is ignored
- Claiming a closed epoch with zero accrual still marks it claimed
- Minting happens once per `claim()` call after the loop, not per epoch

## Revert Conditions

- Invalid epoch duration
- Epoch still active
- Claiming an open epoch
- Double-claiming a closed epoch

## Test Anchors

- `test/ProtocolCore.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
- `test/e2e/AbusePathsE2E.t.sol`
