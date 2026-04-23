# Scuro E2E Scenario Matrix

This matrix is the completeness gate for the E2E suite. Every listed flow or edge case must map to at least one concrete test.

| Scenario ID | Flow / Edge Case | Test Coverage |
| --- | --- | --- |
| `SMOKE-BOOTSTRAP` | Full-stack wiring, catalog flags, controller-engine authorization, expression ownership, timelock wiring | `SmokeE2ETest.test_WiringAndCatalogBootstrap` |
| `SMOKE-GOV` | Minimal stake/delegate/propose/vote/queue/execute path | `SmokeE2ETest.test_MinimalGovernanceFlow` |
| `SMOKE-SOLO` | Minimal number-picker play with expression token attribution | `SmokeE2ETest.test_MinimalSoloPlayFlow` |
| `SMOKE-SLOT` | Minimal slot play with expression token attribution | `SmokeE2ETest.test_MinimalSlotPlayFlow` |
| `FLOW-SOLO-END2END` | Number-picker play, accrual, epoch close, developer claim | `UserFlowsE2ETest.test_SoloFlow_EndToEnd` |
| `FLOW-SOLO-MULTI` | Multi-play aggregation in one epoch | `UserFlowsE2ETest.test_SoloMultiPlay_AggregatesActivityWithinEpoch` |
| `FLOW-EXPR-TRANSFER` | Expression NFT transfer redirects later-booked accrual in immediate-settlement flow | `UserFlowsE2ETest.test_TransferredExpressionRedirectsOnlyFutureAccruals` |
| `FLOW-SLOT-END2END` | Slot play, accrual, epoch close, developer claim | `UserFlowsE2ETest.test_SlotFlow_EndToEnd` |
| `FLOW-SLOT-EXPR-TRANSFER` | Slot expression NFT transfer redirects later-booked accrual | `UserFlowsE2ETest.test_SlotTransferredExpressionRedirectsOnlyFutureAccruals` |
| `FLOW-GOV-CONFIG` | Governance changes live config and behavior | `UserFlowsE2ETest.test_GovernanceFlow_ChangesEpochDurationAndBehavior` |
| `FLOW-MULTI-EPOCH` | Closed epochs remain claimable later | `UserFlowsE2ETest.test_MultiEpochFlow_ClosedEpochsRemainClaimableLater` |
| `ABUSE-SOLO-INPUTS` | Invalid selection, zero wager, missing approval | `AbusePathsE2ETest.test_NumberPickerRejectsInvalidSelectionZeroWagerAndMissingApproval` |
| `ABUSE-SOLO-PENDING` | Retired number-picker module, pending finalize, duplicate finalize | `AbusePathsE2ETest.test_NumberPickerRejectsRetiredModuleAndDuplicateFinalize` |
| `ABUSE-SLOT-PENDING` | Inactive preset, pending finalize, duplicate settlement | `AbusePathsE2ETest.test_SlotRejectsInactivePresetPendingFinalizeAndDuplicateSettlement` |
| `ABUSE-SLOT-LIFECYCLE` | Retired slot module allows settlement but rejects new launches; disabled module blocks progress | `AbusePathsE2ETest.test_SlotLifecycleAllowsRetiredSettlementButRejectsNewLaunchesAndDisabledProgress` |
| `ABUSE-DEVELOPER-EPOCHS` | Early close, claim before close, zero-accrual claim, duplicate claim | `AbusePathsE2ETest.test_DeveloperRewardsRejectEarlyCloseClaimBeforeCloseDuplicateClaimAndZeroAccrualMint` |
| `ABUSE-GOV` | Insufficient proposer votes, timelock delay enforcement | `AbusePathsE2ETest.test_GovernanceRejectsInsufficientVotesAndEnforcesTimelockDelay` |
| `ABUSE-ROLES` | Unauthorized catalog and settlement calls | `AbusePathsE2ETest.test_CatalogAndSettlementRejectUnauthorizedCallers` |
| `ABUSE-EXPRESSIONS` | Inactive and mismatched expression NFTs are rejected at settlement | `AbusePathsE2ETest.test_SettlementRejectsInactiveOrMismatchedExpressions` |
