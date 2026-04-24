# Governance Playbook

## Purpose

This playbook covers the minimum chain of calls a client needs for proposal-driven protocol changes.

## Sequence

1. Stake SCU into `sSCU`.
2. Delegate voting power to the proposer or delegatee.
3. Build proposal calldata targeting governed contracts such as `DeveloperRewards` or `GameCatalog`.
4. Call the standard OpenZeppelin Governor `propose(...)` flow on `ScuroGovernor`.
5. After `votingDelay`, cast votes through the governor.
6. After the proposal succeeds and `proposalNeedsQueuing` is true, queue it into the timelock.
7. After the timelock delay, execute it through the governor.

## Required Reads

- `votingDelay()`, `votingPeriod()`, `quorum(blockNumber)`, `proposalThreshold()`, `state(proposalId)`, and `proposalNeedsQueuing(proposalId)` on the governor
- `getVotes(...)` and checkpoint reads inherited from `ERC20Votes` on `sSCU`

## Client Notes

- `ScuroGovernor` is intentionally thin; most proposal mechanics come from inherited OpenZeppelin Governor interfaces.
- The most relevant protocol-specific client concern is mapping proposals to governed contracts and timelock-controlled roles.
- Future module additions can deploy controller/engine implementations separately, then propose `GameCatalog.registerModule(...)` once the timelock has `REGISTRAR_ROLE`.

## Relevant References

- [ScuroGovernor](../reference/scuro-governor.md)
- [ScuroStakingToken](../reference/scuro-staking-token.md)
- [DeveloperRewards](../reference/developer-rewards.md)
