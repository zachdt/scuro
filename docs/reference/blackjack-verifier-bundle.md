# BlackjackVerifierBundle

## Purpose

`BlackjackVerifierBundle` maps blackjack public-input structs into the generated verifier contracts for initial deal, action resolution, and showdown.

## Caller Model

- The blackjack engine calls the `verify*` methods
- Admin tooling can rotate verifier addresses

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `CONFIG_ROLE`

## Constructor And Config

- `constructor(admin, initialDealVerifierAddress, actionVerifierAddress, showdownVerifierAddress)`
- Mutable verifier slots:
  - `initialDealVerifier`
  - `actionVerifier`
  - `showdownVerifier`

## Public API

- `setVerifiers(initialDealVerifierAddress, actionVerifierAddress, showdownVerifierAddress)`
- `verifyInitialDeal(proofData, inputs)`
- `verifyAction(proofData, inputs)`
- `verifyShowdown(proofData, inputs)`

## Events

- No custom bundle events

## State And Lifecycle Notes

- Signal ordering is fixed and exposed in generated metadata
- Bundle verification is a pure read path; session mutation happens in the engine only after a successful verification result

## Revert Conditions

- Missing `CONFIG_ROLE` on verifier rotation
- Proof decode or verifier-call failures bubble up as failed engine verification

## Test Anchors

- `test/BlackjackController.t.sol`
- `script/SmokeRealProofHands.s.sol`
