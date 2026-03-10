# Scuro E2E Scenario Matrix

This matrix is the completeness gate for the E2E suite. Every listed flow or edge case must map to at least one concrete test.

| Scenario ID | Flow / Edge Case | Test Coverage |
| --- | --- | --- |
| `SMOKE-BOOTSTRAP` | Full-stack wiring, roles, registry flags, timelock wiring | `SmokeE2ETest.test_WiringAndRegistryBootstrap` |
| `SMOKE-GOV` | Minimal stake/delegate/propose/vote/queue/execute path | `SmokeE2ETest.test_MinimalGovernanceFlow` |
| `SMOKE-SOLO` | Minimal number-picker play | `SmokeE2ETest.test_MinimalSoloPlayFlow` |
| `SMOKE-TOURNAMENT` | Minimal poker tournament settlement | `SmokeE2ETest.test_MinimalTournamentFlow` |
| `SMOKE-PVP` | Minimal PvP settlement | `SmokeE2ETest.test_MinimalPvPFlow` |
| `FLOW-SOLO-END2END` | Solo play, accrual, epoch close, creator claim | `UserFlowsE2ETest.test_SoloFlow_EndToEnd` |
| `FLOW-SOLO-MULTI` | Multi-play aggregation in one epoch | `UserFlowsE2ETest.test_SoloMultiPlay_AggregatesActivityWithinEpoch` |
| `FLOW-TOURNAMENT-END2END` | Tournament lifecycle, reward mint, replay guard | `UserFlowsE2ETest.test_TournamentFlow_EndToEnd` |
| `FLOW-PVP-END2END` | PvP lifecycle, reward mint, replay guard | `UserFlowsE2ETest.test_PvPFlow_EndToEnd` |
| `FLOW-GOV-CONFIG` | Governance changes live config and behavior | `UserFlowsE2ETest.test_GovernanceFlow_ChangesEpochDurationAndBehavior` |
| `FLOW-MULTI-EPOCH` | Closed epochs remain claimable later | `UserFlowsE2ETest.test_MultiEpochFlow_ClosedEpochsRemainClaimableLater` |
| `ABUSE-SOLO-INPUTS` | Invalid selection, zero wager, missing approval | `AbusePathsE2ETest.test_NumberPickerRejectsInvalidSelectionZeroWagerAndMissingApproval` |
| `ABUSE-SOLO-PENDING` | Inactive engine, pending finalize, duplicate finalize | `AbusePathsE2ETest.test_NumberPickerRejectsInactiveEngineAndDuplicateFinalize` |
| `ABUSE-SETTLEMENT-LIFECYCLE` | Premature tournament settlement, inactive-engine rejection for new tournament/PvP starts, completed tournament settlement after deactivation | `AbusePathsE2ETest.test_TournamentAndPvPRejectInactiveEnginesPrematureSettlementAndReplay` |
| `ABUSE-CREATOR-EPOCHS` | Early close, claim before close, zero-accrual claim, duplicate claim | `AbusePathsE2ETest.test_CreatorRewardsRejectEarlyCloseClaimBeforeCloseDuplicateClaimAndZeroAccrualMint` |
| `ABUSE-GOV` | Insufficient proposer votes, timelock delay enforcement | `AbusePathsE2ETest.test_GovernanceRejectsInsufficientVotesAndEnforcesTimelockDelay` |
| `ABUSE-POKER` | Bad phases, bad proofs, timeout, fold path, tie path | `AbusePathsE2ETest.test_PokerRejectsDrawProofsOutsideDrawPhase`, `AbusePathsE2ETest.test_PokerRejectsInvalidDrawAndShowdownProofs`, `AbusePathsE2ETest.test_PokerTimeoutClaimsTheCurrentHand`, `AbusePathsE2ETest.test_PokerFoldEndsTheCurrentHand`, `AbusePathsE2ETest.test_PokerTieProofAdvancesToNextHand` |
| `ABUSE-POKER-INIT` | Unauthorized caller cannot initialize poker games directly | `AbusePathsE2ETest.test_PokerEngineRejectsUnauthorizedGameInitialization` |
| `ABUSE-ROLES` | Unauthorized registry and settlement calls | `AbusePathsE2ETest.test_RegistryAndSettlementRejectUnauthorizedCallers` |
