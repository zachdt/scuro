# Blackjack Session Spec

## Product Identity And Session Owner

- Product: double-deck blackjack
- Session owner: `BlackjackController`
- Engine: blackjack engine
- Session model: one player, one wagered blackjack hand tree, optional splits up to four total hands

This page is the canonical blackjack product spec.

## Session Creation Inputs And Actor Roles

- Player supplies `wager`, `playRef`, `playerKeyCommitment`, and `expressionTokenId`
- Controller burns the opening wager before the engine opens the session
- Coordinator remains responsible for proof-backed deal, action, peek, and showdown transitions
- Any caller may settle a completed session through the controller

## Randomness / Proof Source

- Card state is private and proof-backed
- Each session uses a fresh independently shuffled 104-card shoe
- The shuffle model is continuous shuffle in product terms: no cross-session shoe depletion, penetration tracking, or carry-over state
- Dealer hidden-card behavior, peek behavior, insurance windows, surrender windows, and final settlement must all be enforced by the proof system and surfaced in session state

## Rules And Economic Parameters

### Core Parameters

- Deck composition: two standard 52-card decks
- Blackjack payout: `3:2`
- Standard winning hand payout: `1:1`
- Push payout: return of the resolved hand wager
- Insurance payout: `2:1`

### Dealer Rules

- Dealer must stand on all `17`s, including soft `17`
- Dealer peeks for blackjack when the upcard is an Ace or any `10`-value card
- If dealer blackjack is confirmed during peek, the session skips ordinary player actions and settles immediately under the precedence rules below

### Player Actions

- `hit`
- `stand`
- `double`
- `split`
- `insurance`
- `surrender`

### Doubling Rules

- Double on any initial two-card hand
- Double after split is allowed on non-terminal split hands
- A doubled hand receives exactly one additional card and then stands automatically

### Splitting Rules

- Maximum of four total hands per session
- Resplitting is allowed until the four-hand cap is reached, except for Aces
- Split Aces may only be split once, producing at most two Ace hands
- Each split Ace hand receives exactly one additional card
- Split Ace hands may not be hit further
- No resplitting Aces

### Surrender Rules

- Early surrender vs dealer `10`-value upcard:
  - surrender is offered before dealer peek resolution
  - the player forfeits half of the active hand wager if surrender is accepted
- Late surrender vs dealer Ace upcard:
  - dealer peeks first
  - if dealer has blackjack, surrender is void and the full hand wager loses
  - if dealer does not have blackjack, surrender is allowed and forfeits half of the active hand wager

### Insurance Rules

- Insurance is offered only when the dealer upcard is an Ace
- Insurance stake is capped at half of the opening hand wager
- Insurance resolves immediately after dealer peek
- If dealer blackjack is confirmed, insurance pays `2:1`
- If dealer blackjack is not present, the insurance stake is lost and the main hand continues

## Lifecycle / State Progression

1. Player opens a session through `BlackjackController.startHand(...)`
2. Coordinator submits the opening proof with:
   - player cards
   - dealer upcard
   - hidden hole-card commitment
   - available opening actions
   - any immediate natural-blackjack resolution
3. If dealer upcard is Ace:
   - insurance window opens
   - dealer peeks for blackjack
   - if blackjack is present, insurance resolves and the hand ends
   - if blackjack is absent, late surrender remains available
4. If dealer upcard is `10`-value:
   - early surrender window opens before blackjack-check resolution
   - if surrender is declined, dealer peek resolves and ordinary play continues
5. Player acts on the active hand until it stands, busts, doubles, or surrenders
6. If a split occurs, the session advances through each hand in order under the split restrictions above
7. Once all player hands are terminal, coordinator submits showdown proof
8. Dealer draw proceeds under the mandatory stand-on-all-17s rule
9. Controller settles the completed session

## Settlement Formulas And Precedence

### Main-Hand Precedence

1. Dealer blackjack confirmed during peek
2. Player blackjack on an original unsplit two-card hand
3. Surrender resolution
4. Dealer draw and ordinary comparison

### Blackjack Rules

- Only an original two-card unsplit player hand is eligible for blackjack payout
- Split hands are not eligible for the `3:2` blackjack premium
- If both player and dealer have blackjack, the main hand pushes
- If dealer has blackjack and player does not, the main hand loses in full

### Insurance Precedence

- Insurance is resolved independently of the main hand
- Insurance never converts a losing main hand into a push; it is a side settlement
- If dealer blackjack is present, insurance pays `2:1` on the insurance stake
- If dealer blackjack is absent, insurance pays `0`

### Surrender Payout

- Surrender pays half of the resolved hand wager back to the player
- The surrendered half is retained as the player loss
- Dealer blackjack overrides late surrender vs Ace when peek confirms blackjack

### Ordinary Comparison

- Player bust: lose hand wager
- Dealer bust: pay `2x` resolved hand wager
- Player total greater than dealer total: pay `2x` resolved hand wager
- Tie: pay `1x` resolved hand wager
- Player total less than dealer total: pay `0`

## Timeouts, Forced Resolution, And Cancellation

- Player action windows still exist per active-hand step
- Missed player action windows convert into a forced stand unless the product later introduces a more specific timeout rule
- Coordinator proof stalls remain an operational concern and should not be silently auto-resolved by clients
- There is no player-side cancellation after the opening deal is accepted

## Observability

Clients must be able to recover:

- opening wager and accumulated burn
- active hand index and hand count
- per-hand wager, total, terminal state, and payout kind
- dealer reveal state, upcard, peek result, and final dealer total
- insurance window status and insurance settlement
- surrender availability and surrender outcome
- completion state and final payout

Reference and implementation-facing reads should continue to come from the concrete engine/controller docs. This page defines the product behavior those reads must eventually represent.

## Implementation Notes

- This spec is the canonical blackjack implementation for the docs set
- Legacy code paths that still assume a 52-card proxy model, no insurance, no surrender, or no Ace-specific split restrictions are migration work, not alternate supported blackjack behavior

## Required Future Implementation Deltas

- Remove the legacy 52-card card model and replace it with a double-deck 104-card card-space and shuffle witness
- Update product-facing config and deployment labels so the live module clearly represents double-deck blackjack
- Extend the action/state model with insurance and surrender actions, windows, and settlement data
- Encode dealer peek behavior for Ace and `10`-value upcards in proof inputs and public session state
- Encode dealer draw-policy constraints so proofs enforce stand on all `17`s, including soft `17`
- Encode split-Ace restrictions, blackjack-eligibility restrictions, and double-after-split behavior in the verifier/public-input model
