# Game Module User Flows

This guide captures the current controller and engine flows for each shipped game module in this repository. The diagrams describe the code paths that exist today, including where settlement happens, who is allowed to call each stage, and which off-chain or external component unblocks the next step.

## Current Module Map

| Module | Mode | Controller | Engine | External dependency | Local default config |
| --- | --- | --- | --- | --- | --- |
| NumberPicker | Solo | `NumberPickerAdapter` | `NumberPickerEngine` | VRF coordinator | auto-callback VRF mock |
| Slot Machine | Solo | `SlotMachineController` | `SlotMachineEngine` | VRF coordinator | governed presets (`base`, `free`, `pick`, `hold`) in tests |
| Super Baccarat | Solo | `SuperBaccaratController` | `SuperBaccaratEngine` | VRF coordinator | auto-callback VRF mock |
| Tournament Poker | Tournament | `TournamentController` | `SingleDraw2To7Engine` | coordinator + Groth16 proofs | SB `10`, BB `20`, blind interval `180s`, action window `60s` |
| PvP Poker | PvP | `PvPController` | `SingleDraw2To7Engine` | coordinator + Groth16 proofs | SB `10`, BB `20`, blind interval `180s`, action window `60s` |
| Chemin de Fer | PvP | `CheminDeFerController` | `CheminDeFerEngine` | VRF coordinator | join window `60s` |
| Blackjack | Solo | `BlackjackController` | `SingleDeckBlackjackEngine` | coordinator + Groth16 proofs | action window `60s` |

## NumberPicker

Key runtime notes:
- The player enters through `NumberPickerAdapter`, which burns the wager before asking the engine for randomness.
- Win logic is `rollResult > selection`; payout is `wager * 100 / selection`.
- In the default local setup, the VRF mock calls back immediately, so `play()` records the request and finalizes in one transaction.
- Developer accrual is based on the wager amount that was burned for the request.

```mermaid
sequenceDiagram
    autonumber
    actor Player
    participant Adapter as NumberPickerAdapter
    participant Catalog as GameCatalog
    participant Settlement as ProtocolSettlement
    participant Engine as NumberPickerEngine
    participant VRF as VRF Coordinator

    Player->>Adapter: play(wager, selection, playRef, expressionTokenId)
    Adapter->>Catalog: isLaunchableController(this)
    Adapter->>Settlement: burnPlayerWager(player, wager)
    Adapter->>Engine: requestPlay(player, wager, selection, playRef)
    Engine->>Catalog: isAuthorizedControllerForEngine(adapter, engine)
    Engine->>VRF: requestRandomWords(...)
    VRF->>Engine: rawFulfillRandomWords(requestId, randomWords)
    Note over Engine: rollResult = (randomWord % 100) + 1<br/>isWin = rollResult > selection<br/>payout = wager * 100 / selection when winning
    Adapter->>Adapter: record expressionTokenId
    Adapter->>Catalog: isSettlableController(this)
    Adapter->>Engine: getSettlementOutcome(requestId)
    Adapter->>Engine: getOutcome(requestId)
    Adapter->>Settlement: mintPlayerReward(player, payout)
    Adapter->>Settlement: accrueDeveloperForExpression(expressionTokenId, wager)
```

## Slot Machine

Key runtime notes:
- The player enters through `SlotMachineController`, which burns the stake before asking the engine to launch a preset-driven spin.
- The engine stores immutable governed presets and resolves one atomic spin from a single randomness seed.
- The current engine supports a ways-based base game plus bounded `free spins`, `pick bonus`, and `hold-and-spin` feature families.
- Developer accrual is based on the original stake amount that was burned for the spin.

```mermaid
sequenceDiagram
    autonumber
    actor Player
    actor Caller as Any caller
    participant Controller as SlotMachineController
    participant Catalog as GameCatalog
    participant Settlement as ProtocolSettlement
    participant Engine as SlotMachineEngine
    participant VRF as VRF Coordinator

    Player->>Controller: spin(stake, presetId, playRef, expressionTokenId)
    Controller->>Catalog: isLaunchableController(this)
    Controller->>Settlement: burnPlayerWager(player, stake)
    Controller->>Engine: requestSpin(player, stake, presetId, playRef)
    Engine->>Catalog: isAuthorizedControllerForEngine(controller, engine)
    Engine->>VRF: requestRandomWords(...)
    VRF->>Engine: rawFulfillRandomWords(spinId, randomWords)
    Note over Engine: Resolve base grid<br/>bounded bonus families<br/>enforce payout and event caps
    Controller->>Catalog: isSettlableController(this)
    Controller->>Engine: getSettlementOutcome(spinId)
    Controller->>Settlement: mintPlayerReward(player, payout)
    Controller->>Settlement: accrueDeveloperForExpression(expressionTokenId, stake)

    opt delayed VRF environment
        Caller->>Controller: settle(spinId)
    end
```

## Tournament Poker

Key runtime notes:
- `TournamentController` stores a reusable tournament configuration, then launches individual two-player games under that configuration.
- This is not a bracket manager. The controller does not track standings, rounds, or automatic advancement.
- `startingStack` is an internal chip stack for the poker engine. Settlement still pays the fixed `rewardPool`, not the final chip count.
- The poker engine loops hand-by-hand until one player stack reaches zero. Then anyone can call `reportOutcome`.

```mermaid
sequenceDiagram
    autonumber
    actor Operator
    actor Coordinator
    actor P1 as Player 1
    actor P2 as Player 2
    actor Caller as Any caller
    participant Controller as TournamentController
    participant Catalog as GameCatalog
    participant Settlement as ProtocolSettlement
    participant Engine as SingleDraw2To7Engine
    participant Verifier as PokerVerifierBundle

    Operator->>Controller: createTournament(entryFee, rewardPool, startingStack, expressionTokenId)
    Controller->>Catalog: isLaunchableController(this)
    Controller-->>Operator: tournamentId

    Operator->>Controller: startGameForPlayers(tournamentId, p1, p2)
    Controller->>Catalog: isLaunchableController(this)
    Controller->>Settlement: burnPlayerWager(p1, entryFee)
    Controller->>Settlement: burnPlayerWager(p2, entryFee)
    Controller->>Engine: initializeGame(gameId, [p1,p2], [stack,stack], entryFee, rewardPool)
    Engine->>Catalog: isAuthorizedControllerForEngine(controller, engine)
    Note over Engine: matchState = Active<br/>phase = AwaitingInitialDeal<br/>small blind and big blind posted immediately

    Coordinator->>Engine: submitInitialDealProof(...)
    Engine->>Verifier: verifyInitialDeal(...)
    Note over Engine: phase = PreDrawBetting<br/>deadlineAt = now + 60s

    P1->>Engine: bet(...) or fold()
    P2->>Engine: bet(...) or fold()
    Note over Engine: if bets match, phase -> DrawDeclaration

    P2->>Engine: declareDraw(cardIndices)
    P1->>Engine: declareDraw(cardIndices)
    Note over Engine: phase = DrawProofPending

    Coordinator->>Engine: submitDrawProof(player1, ...)
    Engine->>Verifier: verifyDraw(...)
    Coordinator->>Engine: submitDrawProof(player2, ...)
    Engine->>Verifier: verifyDraw(...)
    Note over Engine: phase = PostDrawBetting<br/>deadlineAt = now + 60s

    P2->>Engine: bet(...) or fold()
    P1->>Engine: bet(...) or fold()
    Note over Engine: if bets match, phase -> ShowdownProofPending

    Coordinator->>Engine: submitShowdownProof(winner, isTie, ...)
    Engine->>Verifier: verifyShowdown(...)
    Note over Engine: if both stacks remain > 0,<br/>dealer rotates and next hand starts<br/>if one stack reaches 0, matchState = Completed

    Caller->>Controller: reportOutcome(gameId)
    Controller->>Catalog: isSettlableController(this)
    Controller->>Engine: isGameOver(gameId)
    Controller->>Engine: getOutcomes(gameId)
    Controller->>Settlement: mintPlayerReward(winner(s), rewardPool split)
    Controller->>Settlement: accrueDeveloperForExpression(expressionTokenId, rewardPool + 2 * entryFee)
```

## Super Baccarat

Key runtime notes:
- `SuperBaccaratController` is a standard solo controller: it burns the wager up front, records the `expressionTokenId`, and settles after the engine resolves.
- The engine deals a fresh eight-deck punto banco shoe for every round and applies the classic automated tableau. No manual draw decisions are exposed.
- Player and banker picks treat ties as pushes. Gross-return multipliers are hardcoded so player, banker, and tie selections are EV-neutral over the exact eight-deck odds.

```mermaid
sequenceDiagram
    autonumber
    actor Player
    actor Caller as Any caller
    participant Controller as SuperBaccaratController
    participant Catalog as GameCatalog
    participant Settlement as ProtocolSettlement
    participant Engine as SuperBaccaratEngine
    participant VRF as VRF Coordinator

    Player->>Controller: play(wager, side, playRef, expressionTokenId)
    Controller->>Catalog: isLaunchableController(this)
    Controller->>Settlement: burnPlayerWager(player, wager)
    Controller->>Engine: requestPlay(player, wager, side, playRef)
    Engine->>Catalog: isAuthorizedControllerForEngine(controller, engine)
    Engine->>VRF: requestRandomWords(...)
    VRF->>Engine: rawFulfillRandomWords(requestId, randomWords)
    Note over Engine: Resolve fresh 8-deck baccarat round<br/>Apply automated tableau<br/>Compute EV-neutral payout or push

    Caller->>Controller: settle(sessionId)
    Controller->>Catalog: isSettlableController(this)
    Controller->>Engine: getSettlementOutcome(sessionId)
    Controller->>Engine: getRound(sessionId)
    Controller->>Settlement: mintPlayerReward(player, payout)
    Controller->>Settlement: accrueDeveloperForExpression(expressionTokenId, wager)
```

## PvP Poker

Key runtime notes:
- `PvPController` starts a single heads-up match directly; there is no reusable tournament record.
- The poker hand state machine is the same `SingleDraw2To7Engine` used by the tournament module.
- Stakes are burned up front, and settlement later pays the session `rewardPool`.
- As with tournament poker, settlement is triggered only after the engine reports `Completed`.

```mermaid
sequenceDiagram
    autonumber
    actor Operator
    actor Coordinator
    actor P1 as Player 1
    actor P2 as Player 2
    actor Caller as Any caller
    participant Controller as PvPController
    participant Catalog as GameCatalog
    participant Settlement as ProtocolSettlement
    participant Engine as SingleDraw2To7Engine
    participant Verifier as PokerVerifierBundle

    Operator->>Controller: createSession(p1, p2, stake, rewardPool, startingStack, expressionTokenId)
    Controller->>Catalog: isLaunchableController(this)
    Controller->>Settlement: burnPlayerWager(p1, stake)
    Controller->>Settlement: burnPlayerWager(p2, stake)
    Controller->>Engine: initializeGame(sessionId, [p1,p2], [stack,stack], stake, rewardPool)
    Engine->>Catalog: isAuthorizedControllerForEngine(controller, engine)

    Note over Engine: Hand loop is identical to Tournament Poker:<br/>AwaitingInitialDeal -> PreDrawBetting -> DrawDeclaration -> DrawProofPending -> PostDrawBetting -> ShowdownProofPending<br/>The loop repeats until one player stack reaches zero

    Coordinator->>Engine: submitInitialDealProof(...)
    Engine->>Verifier: verifyInitialDeal(...)
    P1->>Engine: bet(...) / fold() / declareDraw(...)
    P2->>Engine: bet(...) / fold() / declareDraw(...)
    Coordinator->>Engine: submitDrawProof(...)
    Engine->>Verifier: verifyDraw(...)
    Coordinator->>Engine: submitShowdownProof(...)
    Engine->>Verifier: verifyShowdown(...)

    Caller->>Controller: settleSession(sessionId)
    Controller->>Catalog: isSettlableController(this)
    Controller->>Engine: isGameOver(sessionId)
    Controller->>Engine: getOutcomes(sessionId)
    Controller->>Settlement: mintPlayerReward(winner(s), rewardPool split)
    Controller->>Settlement: accrueDeveloperForExpression(expressionTokenId, rewardPool + 2 * stake)
```

## Blackjack

Key runtime notes:
- `BlackjackController` is a solo controller; only one player address is tracked by the engine.
- The player burns the initial wager up front. `doubleDown` and `split` can require an additional burn equal to the active hand wager.
- The coordinator is responsible for initial deal proofs, post-action proofs, and showdown proofs.
- If the player misses the action window, `claimPlayerTimeout()` converts the pending move into a forced stand.

```mermaid
sequenceDiagram
    autonumber
    actor Player
    actor Coordinator
    actor Caller as Any caller
    participant Controller as BlackjackController
    participant Catalog as GameCatalog
    participant Settlement as ProtocolSettlement
    participant Engine as SingleDeckBlackjackEngine
    participant Verifier as BlackjackVerifierBundle

    Player->>Controller: startHand(wager, playRef, playerKeyCommitment, expressionTokenId)
    Controller->>Catalog: isLaunchableController(this)
    Controller->>Settlement: burnPlayerWager(player, wager)
    Controller->>Engine: openSession(player, wager, playRef, playerKeyCommitment)
    Engine->>Catalog: isAuthorizedControllerForEngine(controller, engine)
    Note over Engine: phase = AwaitingInitialDeal<br/>totalBurned = wager<br/>handCount = 1

    Coordinator->>Engine: submitInitialDealProof(...)
    Engine->>Verifier: verifyInitialDeal(...)
    Note over Engine: if payout > 0 or immediateResultCode != 0,<br/>phase = Completed<br/>otherwise phase = AwaitingPlayerAction with deadlineAt = now + 60s

    Player->>Controller: hit() / stand() / doubleDown() / split()
    Controller->>Catalog: isSettlableController(this)
    Controller->>Engine: requiredAdditionalBurn(sessionId, action)
    Controller->>Settlement: burnPlayerWager(player, additionalBurn)
    Controller->>Engine: declareAction(sessionId, player, action, additionalBurn)
    Note over Engine: phase = AwaitingCoordinator<br/>pendingAction = action

    Coordinator->>Engine: submitActionProof(...)
    Engine->>Verifier: verifyAction(...)
    Note over Engine: phase returns to AwaitingPlayerAction<br/>or remains AwaitingCoordinator for showdown

    alt Player times out during AwaitingPlayerAction
        Caller->>Controller: claimPlayerTimeout(sessionId)
        Controller->>Catalog: isSettlableController(this)
        Controller->>Engine: claimPlayerTimeout(sessionId)
        Note over Engine: pendingAction = STAND<br/>phase = AwaitingCoordinator
    else Player stands or action path reaches showdown
        Coordinator->>Engine: submitShowdownProof(...)
        Engine->>Verifier: verifyShowdown(...)
        Note over Engine: phase = Completed<br/>payout is fixed on session state
    end

    Caller->>Controller: settle(sessionId)
    Controller->>Catalog: isSettlableController(this)
    Controller->>Engine: getSettlementOutcome(sessionId)
    Controller->>Settlement: mintPlayerReward(player, payout)
    Controller->>Settlement: accrueDeveloperForExpression(expressionTokenId, totalBurned)
```

## Chemin De Fer

Key runtime notes:
- `CheminDeFerController` does not use the generic `PvPController`; it owns its own banker-opened table lifecycle.
- The banker escrows the full table limit up front. Takers can join permissionlessly until the banker closes, the join window expires, or the table auto-closes at full capacity.
- Resolution is a single automated baccarat round. The only “chemin de fer” element preserved here is the player-banked table shape; there are no manual draw decisions.
- Developer accrual is booked only on matched exposure, not on any refunded unmatched banker capacity.

```mermaid
sequenceDiagram
    autonumber
    actor Banker
    actor Taker1 as Taker
    actor Taker2 as Taker
    actor Caller as Any caller
    participant Controller as CheminDeFerController
    participant Catalog as GameCatalog
    participant Settlement as ProtocolSettlement
    participant Engine as CheminDeFerEngine
    participant VRF as VRF Coordinator

    Banker->>Controller: openTable(bankerMaxBet, playRef, expressionTokenId)
    Controller->>Catalog: isLaunchableController(this)
    Controller->>Settlement: burnPlayerWager(banker, bankerMaxBet)

    Taker1->>Controller: take(tableId, amount)
    Taker2->>Controller: take(tableId, amount)
    Controller->>Settlement: burnPlayerWager(taker, amount)
    Note over Controller: totalPlayerTake <= playerTakeCap(bankerEscrow)

    alt banker closes or join window expires or table fills
        Banker->>Controller: closeTable(tableId)
        Caller->>Controller: forceCloseTable(tableId)
        Note over Controller: matchedBankerRisk and unmatched refund are frozen
        Controller->>Engine: requestResolution(tableId, playRef)
        Engine->>Catalog: isAuthorizedControllerForEngine(controller, engine)
        Engine->>VRF: requestRandomWords(...)
        VRF->>Engine: rawFulfillRandomWords(requestId, randomWords)
    else no takers join
        Banker->>Controller: cancelTable(tableId)
        Controller->>Settlement: mintPlayerReward(banker, bankerEscrow)
    end

    Caller->>Controller: settle(tableId)
    Controller->>Catalog: isSettlableController(this)
    Controller->>Engine: getRound(tableId)
    Note over Controller: Banker win -> banker receives matched pot + refund<br/>Player win -> takers split matched pot pro rata<br/>Tie -> matched exposure refunds
    Controller->>Settlement: mintPlayerReward(...)
    Controller->>Settlement: accrueDeveloperForExpression(expressionTokenId, matchedExposure)
```

## Shared Lifecycle Rules

- Players never call `ProtocolSettlement` directly. Controllers are the only settlement callers.
- `LIVE` modules can launch and settle. `RETIRED` modules cannot launch new sessions but can still settle in-flight sessions. `DISABLED` modules halt settlement and engine progress.
- Expression compatibility is enforced at settlement time by engine type and active status, not by module `configHash`.
- Poker and blackjack both depend on a coordinator to submit valid Groth16-backed proofs. Player timeouts exist only for player-clock phases, not for stalled coordinator proof submission.

## Source Files

- [ProtocolSettlement](../src/ProtocolSettlement.sol)
- [GameCatalog](../src/GameCatalog.sol)
- [NumberPickerAdapter](../src/controllers/NumberPickerAdapter.sol)
- [NumberPickerEngine](../src/engines/NumberPickerEngine.sol)
- [SlotMachineController](../src/controllers/SlotMachineController.sol)
- [SlotMachineEngine](../src/engines/SlotMachineEngine.sol)
- [TournamentController](../src/controllers/TournamentController.sol)
- [PvPController](../src/controllers/PvPController.sol)
- [SingleDraw2To7Engine](../src/engines/SingleDraw2To7Engine.sol)
- [BlackjackController](../src/controllers/BlackjackController.sol)
- [SingleDeckBlackjackEngine](../src/engines/SingleDeckBlackjackEngine.sol)
