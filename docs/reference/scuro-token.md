# ScuroToken

## Purpose

`ScuroToken` is the shared SCU ERC20 used for wagers, settlement payouts, and developer rewards.

## Caller Model

- Players approve settlement and staking flows
- Settlement and rewards contracts mint with `MINTER_ROLE`

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `MINTER_ROLE`

## Constructor And Config

- `constructor(admin)` sets token name `Scuro Protocol Token` and symbol `SCU`

## Public API

- `mint(to, amount)`
- `nonces(owner)`
- Standard inherited ERC20, ERC20Burnable, ERC20Permit, and ERC20Votes entrypoints

## Events

- Standard ERC20 and ERC20Votes events only

## State And Lifecycle Notes

- `burnFrom` is inherited and used by `ProtocolSettlement`
- Voting checkpoints are inherited from `ERC20Votes`

## Revert Conditions

- Missing `MINTER_ROLE`
- Standard ERC20 approval and balance failures

## Test Anchors

- `test/ProtocolCore.t.sol`
- `script/e2e_deploy_smoke.sh`
