# Blackjack SDK Handoff

This handoff covers the canonical double-deck blackjack product surface for SDK and frontend work.

The product rules and economics live in the [Blackjack session spec](../session-specs/blackjack.md). This page summarizes the SDK-facing implications of that canonical spec.

## Config Marker

- Blackjack module compatibility should route off the canonical double-deck blackjack module metadata and the eventual refreshed manifest/ABI surface
- New integrations should not key themselves to retired single-deck blackjack naming

## Card Proxy Encoding

- The canonical blackjack product is double-deck and therefore needs a 104-card card space rather than the legacy 52-card proxy model
- SDKs should expect a dedicated double-deck card encoding and should not hardcode single-deck assumptions into rank, suit, or sentinel helpers
- Natural-blackjack, peek, insurance, surrender, and split restrictions should all be proof-derived rather than reconstructed client-side

## Canonical Engine Read Shape

SDKs should expect blackjack session reads to expose, at minimum:

- player hand cards in hand order
- dealer visible-card state, including hole-card and peek state
- active hand index and hand count
- per-hand wager, value, terminal state, and payout kind
- insurance availability, insurance stake, and insurance settlement
- surrender availability and surrender outcome
- final dealer total and dealer reveal state

Client rule:
- render outcomes from proof-backed session state and settled payout
- do not compute blackjack bonuses, insurance outcomes, or surrender outcomes client-side
- do not infer dealer draw policy client-side; it must be enforced by the proof system

## Payout Kind Enum

- The canonical product requires payout typing that can represent:
  - ordinary loss
  - ordinary push
  - ordinary win
  - surrender
  - insurance win / insurance loss
  - blackjack `3:2`
- Split hands must not be eligible for blackjack premium payout kinds unless explicitly stated otherwise
- The final payout-kind surface should be regenerated from the migrated engine rather than copied from the retired single-deck enum set

## Proof / Coordinator Payload Changes

The canonical double-deck blackjack proofs must publish and verify:

- double-deck card witness data
- dealer peek eligibility and peek outcome
- insurance window and insurance resolution
- early-surrender vs `10` and late-surrender vs Ace behavior
- split-Ace restrictions
- dealer draw-policy enforcement for stand on all `17`s
- per-hand wager, value, terminal state, and payout kind
- dealer reveal state and final dealer total

The important rule is that payout classes, action masks, reveal states, dealer draw behavior, and side-settlement behavior must all be proof-derived rather than trusted as opaque summaries.

## SDK Work Items

- Regenerate blackjack ABIs and protocol manifest from this repo after deployment artifacts are refreshed
- Extend `inspect.blackjackSession()` to return the full canonical double-deck blackjack session state
- Add exported helpers for:
  - double-deck card decoding
  - blackjack payout-kind decoding
  - insurance and surrender state decoding
  - grouping visible cards into per-hand UI groupings
- Update coordinator proof-provider typings for the expanded blackjack proof args and action windows
- Route module compatibility off the canonical double-deck blackjack module metadata

## SDK Team Checklist

- Update generated contract bindings for the migrated blackjack engine surface
- Update manifest/config-hash handling for the canonical double-deck blackjack module
- Add a typed `BlackjackHandPayoutKind` decode surface
- Add a typed `dealerRevealMask` decode surface
- Add typed insurance and surrender decode surfaces
- Add helpers to convert visible blackjack card arrays into per-hand UI groups
- Remove any client-side blackjack bonus, insurance, or surrender reconstruction logic
- Add tests for:
  - dealer Ace upcard with blackjack and insurance win
  - dealer Ace upcard without blackjack and late surrender
  - dealer `10`-value upcard with early surrender
  - split Ace restrictions
  - blackjack `3:2` on original unsplit naturals
  - dealer stand on hard `17` and soft `17`
