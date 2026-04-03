import { access } from "node:fs/promises";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname, "..");
const expected = [
  path.join(ROOT, "fixtures", "generated", "poker_initial_deal.json"),
  path.join(ROOT, "fixtures", "generated", "poker_draw_resolve.json"),
  path.join(ROOT, "fixtures", "generated", "poker_draw_resolve_player1.json"),
  path.join(ROOT, "fixtures", "generated", "poker_showdown.json"),
  path.join(ROOT, "fixtures", "generated", "poker_showdown_tie.json"),
  path.join(ROOT, "fixtures", "generated", "blackjack_initial_deal.json"),
  path.join(ROOT, "fixtures", "generated", "blackjack_peek.json"),
  path.join(ROOT, "fixtures", "generated", "blackjack_action_resolve.json"),
  path.join(ROOT, "fixtures", "generated", "blackjack_showdown.json"),
  path.resolve(ROOT, "..", "src", "verifiers", "generated", "PokerInitialDealVerifier.sol"),
  path.resolve(ROOT, "..", "src", "verifiers", "generated", "PokerDrawResolveVerifier.sol"),
  path.resolve(ROOT, "..", "src", "verifiers", "generated", "PokerShowdownVerifier.sol"),
  path.resolve(ROOT, "..", "src", "verifiers", "generated", "BlackjackInitialDealVerifier.sol"),
  path.resolve(ROOT, "..", "src", "verifiers", "generated", "BlackjackPeekVerifier.sol"),
  path.resolve(ROOT, "..", "src", "verifiers", "generated", "BlackjackActionResolveVerifier.sol"),
  path.resolve(ROOT, "..", "src", "verifiers", "generated", "BlackjackShowdownVerifier.sol")
];

for (const file of expected) {
  await access(file);
}

console.log(`verified ${expected.length} zk artifacts`);
