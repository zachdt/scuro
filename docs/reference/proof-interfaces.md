# Proof Interfaces

## Purpose

These interfaces define the structured public inputs that off-chain coordinators and generated verifier metadata must agree on.

## Interfaces Covered

- `IPokerVerifierBundle`
- `IBlackjackVerifierBundle`

## Caller Model

- Engines build the input structs
- Coordinators generate proofs whose public signals must match the struct ordering
- SDKs should model these structs directly for typed proof submission helpers

## Public API

### `IPokerVerifierBundle`

- `verifyInitialDeal(proof, inputs)`
- `verifyDraw(proof, inputs)`
- `verifyShowdown(proof, inputs)`
- Structs:
  - `InitialDealPublicInputs`
  - `DrawPublicInputs`
  - `ShowdownPublicInputs`

### `IBlackjackVerifierBundle`

- `verifyInitialDeal(proof, inputs)`
- `verifyAction(proof, inputs)`
- `verifyShowdown(proof, inputs)`
- Structs:
  - `InitialDealPublicInputs`
  - `ActionPublicInputs`
  - `ShowdownPublicInputs`

## State And Lifecycle Notes

- Treat these struct definitions as the human-readable twin of generated `proof-inputs.json`
- Field order matters because the verifier bundles flatten these structs into fixed-width signal arrays

## Test Anchors

- `test/TournamentController.t.sol`
- `test/BlackjackController.t.sol`
- `script/SmokeRealProofHands.s.sol`
