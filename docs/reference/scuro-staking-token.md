# ScuroStakingToken

## Purpose

`ScuroStakingToken` is the liquid staking wrapper over SCU and the governance voting token.

## Caller Model

- Players and governors stake and unstake directly
- Governance reads inherited `ERC20Votes` state

## Roles And Permissions

- No custom roles

## Constructor And Config

- `constructor(token)` sets token name `Staked Scuro` and symbol `sSCU`
- The backing asset is immutable and exposed through `asset()`

## Public API

- `asset()`
- `stake(amount)`
- `unstake(amount)`
- `nonces(owner)`
- Standard inherited ERC20, ERC20Permit, and ERC20Votes entrypoints

## Events

- Standard ERC20 and ERC20Votes events only

## State And Lifecycle Notes

- Mint and burn are 1:1 with SCU deposits and withdrawals
- Staking alone does not delegate voting power; clients still need an explicit delegation step

## Revert Conditions

- Zero stake or unstake amount
- Failed SCU transfer in or out

## Test Anchors

- `test/ProtocolCore.t.sol`
- `test/e2e/SmokeE2E.t.sol`
- `script/e2e_deploy_smoke.sh`
