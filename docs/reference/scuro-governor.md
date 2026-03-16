# ScuroGovernor

## Purpose

`ScuroGovernor` is the protocol governor wrapper around OpenZeppelin Governor modules and the timelock.

## Caller Model

- Governance frontends and SDKs use standard Governor calls plus the overrides listed here

## Roles And Permissions

- Role-bearing behavior is delegated to the timelock and inherited Governor modules

## Constructor And Config

- `constructor(token, timelock, votingDelayBlocks, votingPeriodBlocks, proposalThresholdAmount)`
- Quorum is fixed through `GovernorVotesQuorumFraction(4)`

## Public API

- `votingDelay()`
- `votingPeriod()`
- `quorum(blockNumber)`
- `proposalThreshold()`
- `state(proposalId)`
- `proposalNeedsQueuing(proposalId)`
- All other operational flows are inherited from OpenZeppelin Governor contracts

## Events

- Standard inherited Governor and Timelock events

## State And Lifecycle Notes

- This contract mainly resolves multiple inheritance and exposes the resulting configuration
- Clients should treat `proposalNeedsQueuing` as the signal for whether a successful proposal must pass through the timelock queue before execution

## Revert Conditions

- Standard inherited Governor and timelock guardrails

## Test Anchors

- `test/ProtocolCore.t.sol`
- `test/e2e/SmokeE2E.t.sol`
- `test/e2e/UserFlowsE2E.t.sol`
