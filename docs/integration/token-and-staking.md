# Approvals and Staking Playbook

## Purpose

This flow covers the common bootstrap path for player and governance-capable accounts.

## Sequence

1. Read `ScuroToken` and `ScuroStakingToken` addresses from deployment output or the generated manifest.
2. If the client will place wagers through a controller, approve `ProtocolSettlement` to spend SCU.
3. If the client will participate in governance, approve `ScuroStakingToken` to spend SCU.
4. Call `stake(amount)` on `ScuroStakingToken`.
5. Call the inherited governance delegation flow on `sSCU` so voting power becomes active for the intended delegate.

## Reads And Events

- Read `asset()` on `ScuroStakingToken` to confirm the underlying SCU address.
- Watch ERC20 `Approval` and `Transfer` events plus `ERC20Votes` checkpoints if governance tooling needs historical voting power.

## Failure Cases

- `stake(0)` and `unstake(0)` revert.
- Insufficient SCU allowance or balance causes token transfer failure.

## Relevant References

- [ScuroToken](../reference/scuro-token.md)
- [ScuroStakingToken](../reference/scuro-staking-token.md)
- [ScuroGovernor](../reference/scuro-governor.md)
