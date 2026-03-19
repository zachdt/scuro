# Event Indexing Guide

Scuro is log-friendly but not log-complete. Indexers and SDK caches should reconstruct state from events first, then fill any gaps with targeted view calls.

## Indexing Strategy

1. Bootstrap contract identities from the generated protocol manifest and deployment output labels.
2. Subscribe to module, controller, engine, verifier, token, and rewards events.
3. Materialize local state keyed by `module_id`, `request_id`, `session_id`, `game_id`, `tournament_id`, and `expression_token_id`.
4. Backfill missing or derived fields with read calls such as `getModule`, `getOutcome`, `getSession`, `getHandState`, or `getExpressionMetadata`.

## Event Families

### Lifecycle and registry

- `ModuleRegistered` and `ModuleStatusUpdated`: track module identity, mode, verifier bundle, config hash, reward rate, and lifecycle status.
- `ExpressionMinted` and `ExpressionActiveSet`: track developer attribution inventory and moderation status.
- `EngineRegistered` and `EngineDeactivated`: optional legacy/adjacent registry coverage.

### Value movement

- `PlayerWagerBurned`: records controller-triggered SCU burns.
- `PlayerRewardMinted`: records settlement payouts.
- `DeveloperAccrualRecorded`: records the activity basis plus computed accrual.
- `DeveloperAccrued`, `EpochClosed`, `DeveloperClaimed`: track reward accounting and claims.

### Gameplay

- NumberPicker: `PlayRequested`, `PlayResolved`, `PlayFinalized`
- Slot Machine: `PresetRegistered`, `PresetActiveSet`, `SpinRequested`, `BaseGameResolved`, `FreeSpinsResolved`, `PickBonusResolved`, `HoldAndSpinResolved`, `JackpotAwarded`, `SpinResolved`, `SpinFinalized`
- Poker: `TournamentCreated`, `GameStarted`, `GameSettled`, `SessionCreated`, `SessionSettled`, `HandAwaitingInitialDeal`, `PublicActionTaken`, `DrawDeclared`, `DrawResolved`, `ShowdownSubmitted`
- Blackjack: `HandStarted`, `SessionOpened`, `InitialDealResolved`, `ActionDeclared`, `ActionResolved`, `PlayerTimeoutClaimed`, `ShowdownResolved`, `SessionSettled`

## Fallback Reads

Use reads when events do not carry enough information:

- `GameCatalog.getModule*`: resolve module metadata and lifecycle gates.
- `NumberPickerEngine.getOutcome`: retrieve selection, roll result, and win flag after resolution.
- `SlotMachineEngine.getPresetSummary`, `getSpin`, and `getSpinResult`: recover preset caps, resolved feature flags, and final slot payout details.
- `SingleDraw2To7Engine.getHandState`: reconstruct live poker phase, proof sequences, and deadlines.
- `SingleDeckBlackjackEngine.getSession`: reconstruct the active blackjack hand tree and pending action state.
- `DeveloperExpressionRegistry.getExpressionMetadata`: recover engine type compatibility and original minter.

## Client Rules

- Treat controller settlement events as the final economic record, not engine events.
- Use controller and engine events together for poker/blackjack because engines express the live state machine while controllers express economic completion.
- Do not infer `RETIRED` or `DISABLED` behavior from event gaps; always consult `GameCatalog`.
- Cache `deadlineAt` values but invalidate them on every state transition event because poker and blackjack phases reset deadlines frequently.
