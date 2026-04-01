# Blackjack V2 SDK Handoff

This handoff covers the breaking blackjack-module upgrade that moves suit-aware blackjack semantics into the proof system and on-chain session state.

## Release Marker

- New blackjack config hash label: `single-deck-blackjack-zk-v2`
- Frontends and SDKs should treat this as a new blackjack module version, not an in-place patch on the old config

## Card Proxy Encoding

- Blackjack now uses the shared 52-card proxy model already used by poker
- `rank = card % 13`
- `suit = floor(card / 13)`
- `52` is the empty-card sentinel exposed on unread / unused slots
- Natural-blackjack and suited-natural checks are proof-derived from these proxies, not inferred client-side

## New Engine Read Shape

`SingleDeckBlackjackEngine.getSession(sessionId)` now exposes:

- `playerCards[8]`: flattened player card proxies in hand order
- `dealerCards[4]`: dealer card proxies, with hidden slots set to `CARD_EMPTY`
- `dealerRevealMask`: bitmask describing which dealer slots are revealed
- `hands[i].cardCount`: visible card count for each hand
- `hands[i].payoutKind`: proof-backed payout class for each hand

Client rule:
- render payout from `hands[i].payoutKind` and settled `payout`
- do not compute blackjack bonuses client-side

## Payout Kind Enum

`SingleDeckBlackjackEngine` now exposes these payout-kind constants:

| Value | Label |
| --- | --- |
| `0` | `HAND_PAYOUT_NONE` |
| `1` | `HAND_PAYOUT_LOSS` |
| `2` | `HAND_PAYOUT_PUSH` |
| `3` | `HAND_PAYOUT_EVEN_MONEY` |
| `4` | `HAND_PAYOUT_BLACKJACK_3_TO_2` |
| `5` | `HAND_PAYOUT_SUITED_BLACKJACK_2_TO_1` |

Rule summary:

- suited natural blackjack pays `2:1`
- unsuited natural blackjack pays `3:2`
- player blackjack vs dealer blackjack pushes, even if the player blackjack is suited
- only the opening two-card hand can receive a blackjack bonus kind

## Proof / Coordinator Payload Changes

Blackjack proofs now publish and verify:

- `handCardCounts[4]`
- `handPayoutKinds[4]`
- `playerCards[8]`
- `dealerCards[4]`
- `dealerRevealMask`

Showdown proofs also bind:

- `handValues[4]`
- `handWagers[4]` on the verifier side

The important behavior change is that payout classes, action masks, and revealed cards are now derived from the card witness instead of being trusted as opaque summaries.

## SDK Work Items

- Regenerate blackjack ABIs and protocol manifest from this repo after deployment artifacts are refreshed
- Extend `inspect.blackjackSession()` to return `playerCards`, `dealerCards`, `dealerRevealMask`, `hands[].cardCount`, and `hands[].payoutKind`
- Add exported helpers for:
  - blackjack payout-kind decoding
  - shared card-proxy decoding (`rank`, `suit`, sentinel handling)
  - grouping flattened `playerCards` into visible per-hand arrays using `hands[].cardCount`
- Update coordinator proof-provider typings for the expanded blackjack proof args
- Route module compatibility off the new config hash label `single-deck-blackjack-zk-v2`

## SDK Team Checklist

- Update generated contract bindings for `SingleDeckBlackjackEngine`
- Update manifest/config-hash handling for blackjack v2
- Add a typed `BlackjackHandPayoutKind` decode surface
- Add a typed `dealerRevealMask` decode surface
- Add helpers to convert flattened blackjack card arrays into per-hand UI groups
- Remove any client-side blackjack bonus reconstruction logic
- Add tests for suited blackjack, unsuited blackjack, push-natural precedence, hidden dealer hole cards, and payout-kind decoding
