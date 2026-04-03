import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { generateBlackjackArtifact } from "./lib/blackjack-proof.mjs";

const ROOT = path.resolve(import.meta.dirname, "..");
const OUTPUT_DIR = path.join(ROOT, "fixtures", "generated");

async function generate() {
    await mkdir(OUTPUT_DIR, { recursive: true });

    // Scenario:
    // Player: 10, 8 (18)
    // Dealer: Ace (Up), 5 (Hidden) -> Total 16
    // 1. Initial Deal -> Phase 2 (Pre-Play Decision due to Ace)
    // 2. Action (Hit) -> Phase 5 (AwaitingPlayerAction)
    // 3. Action (Stand) -> Phase 6 (AwaitingCoordinatorAction / Showdown)
    // 4. Showdown -> Phase 7 (Completed)

    const sessionId = 1;
    const playerKey = [311, 312];
    const playerSalt = 1001;
    const dealerSalt = 1002;
    const deckSalt = 1003;
    const playerCipherSalt = 703;
    const dealerCipherSalt = 704;
    const handNonce = "0x" + BigInt(701).toString(16).padStart(64, "0");

    const playerCardsVisible = [9, 7]; // 10, 8
    const dealerCardsFull = [6, 4, 9]; // 7, 5, 10
    
    // 1. Initial Deal
    console.log("Generating Initial Deal...");
    const initialDealArtifact = await generateBlackjackArtifact({
        root: ROOT,
        phase: "initial-deal",
        witness: {
            sessionId,
            handNonce,
            playerKey,
            playerCards: playerCardsVisible,
            dealerCards: dealerCardsFull,
            playerSalt,
            dealerSalt,
            deckSalt,
            playerCipherSalt,
            dealerCipherSalt,
            baseWager: 100
        },
        name: "blackjack_smoke_initial"
    });
    await writeFile(path.join(OUTPUT_DIR, "blackjack_smoke_initial.json"), JSON.stringify(initialDealArtifact, null, 2));

    const deckCommitment = initialDealArtifact.input.deckCommitment;
    const initialPlayerStateCommitment = initialDealArtifact.input.playerStateCommitment;
    const initialDealerStateCommitment = initialDealArtifact.input.dealerStateCommitment;

    // 2. Action (Hit)
    // New Player Card: 2 (Rank 1). Total 10+8+2 = 20.
    const playerCardsAfterHit = [9, 7, 1];
    const newPlayerSalt = 1004;

    console.log("Generating Action (Hit)...");
    const actionHitArtifact = await generateBlackjackArtifact({
        root: ROOT,
        phase: "action",
        witness: {
            sessionId,
            proofSequence: 2,
            pendingAction: 1, // HIT
            deckCommitment,
            playerKey,
            oldPlayerCards: playerCardsVisible,
            playerCards: playerCardsAfterHit,
            dealerCards: dealerCardsFull,
            oldHandCardCounts: [2, 0, 0, 0],
            handCardCounts: [3, 0, 0, 0],
            oldPlayerSalt: playerSalt,
            newPlayerSalt: newPlayerSalt,
            dealerSalt: dealerSalt,
            playerCipherSalt: playerCipherSalt,
            dealerCipherSalt: dealerCipherSalt,
            baseWager: 100,
            phase: 5 // AwaitingPlayerAction
        },
        name: "blackjack_smoke_action_hit"
    });
    await writeFile(path.join(OUTPUT_DIR, "blackjack_smoke_action_hit.json"), JSON.stringify(actionHitArtifact, null, 2));

    // 3. Action (Stand)
    console.log("Generating Action (Stand)...");
    const actionStandArtifact = await generateBlackjackArtifact({
        root: ROOT,
        phase: "action",
        witness: {
            sessionId,
            proofSequence: 3,
            pendingAction: 2, // STAND
            deckCommitment,
            playerKey,
            oldPlayerCards: playerCardsAfterHit,
            playerCards: playerCardsAfterHit,
            dealerCards: dealerCardsFull,
            oldHandCardCounts: [3, 0, 0, 0],
            handCardCounts: [3, 0, 0, 0],
            oldPlayerSalt: newPlayerSalt,
            newPlayerSalt: newPlayerSalt,
            dealerSalt: dealerSalt,
            playerCipherSalt: playerCipherSalt,
            dealerCipherSalt: dealerCipherSalt,
            baseWager: 100,
            phase: 6 // AwaitingCoordinatorAction
        },
        name: "blackjack_smoke_action_stand"
    });
    await writeFile(path.join(OUTPUT_DIR, "blackjack_smoke_action_stand.json"), JSON.stringify(actionStandArtifact, null, 2));

    // 4. Showdown
    console.log("Generating Showdown...");
    const showdownArtifact = await generateBlackjackArtifact({
        root: ROOT,
        phase: "showdown",
        witness: {
            sessionId,
            proofSequence: 4,
            deckCommitment,
            playerKey,
            playerCards: playerCardsAfterHit,
            dealerCards: dealerCardsFull,
            handCardCounts: [3, 0, 0, 0],
            playerSalt: newPlayerSalt,
            dealerSalt,
            baseWager: 100,
            phase: 7, // Completed
            payout: 200 // 100 wager + 100 profit
        },
        name: "blackjack_smoke_showdown"
    });
    await writeFile(path.join(OUTPUT_DIR, "blackjack_smoke_showdown.json"), JSON.stringify(showdownArtifact, null, 2));

    console.log("Smoke fixtures generated successfully in zk/fixtures/generated/");
}

generate().catch(err => {
    console.error(err);
    process.exit(1);
});
