import path from "node:path";
import { execa } from "./lib/execa.mjs";

const ROOT = path.resolve(import.meta.dirname, "..", "..");

try {
  await execa(
    "forge",
    [
      "test",
      "--match-contract",
      "BlackjackControllerTest",
      "--match-test",
      "test_BlackjackRealProofFlowSettlesThroughController",
      "--offline"
    ],
    { cwd: ROOT }
  );
  console.log("blackjack zk artifacts match the checked-in verifier and fixture set");
} catch (error) {
  console.error("blackjack artifact drift detected or blackjack verifier parity is broken");
  console.error("re-sync with: bun run --cwd zk resync");
  throw error;
}
