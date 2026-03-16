# PokerVerifierBundle

## Purpose

`PokerVerifierBundle` maps structured poker proof inputs into the concrete generated verifier contracts.

## Caller Model

- Coordinator-facing engines call the `verify*` methods
- Admin tooling can rotate verifier addresses

## Roles And Permissions

- `DEFAULT_ADMIN_ROLE`
- `CONFIG_ROLE`

## Constructor And Config

- `constructor(admin, initialDealVerifierAddress, drawVerifierAddress, showdownVerifierAddress)`
- Mutable verifier slots:
  - `initialDealVerifier`
  - `drawVerifier`
  - `showdownVerifier`

## Public API

- `setVerifiers(initialDealVerifierAddress, drawVerifierAddress, showdownVerifierAddress)`
- `verifyInitialDeal(proofData, inputs)`
- `verifyDraw(proofData, inputs)`
- `verifyShowdown(proofData, inputs)`

## Events

- No custom bundle events

## State And Lifecycle Notes

- `proofData` is decoded through `Groth16ProofCodec`
- Signal ordering is part of the SDK contract between coordinator software and the verifier bundle; use [Proof Interfaces](./proof-interfaces.md) and generated `proof-inputs.json`

## Revert Conditions

- Missing `CONFIG_ROLE` on verifier rotation
- Proof decode or verifier-call failures collapse into a `false` verification result at the engine layer

## Test Anchors

- `test/TournamentController.t.sol`
- `script/SmokeRealProofHands.s.sol`
