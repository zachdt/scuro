// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BaccaratTypes} from "../src/libraries/BaccaratTypes.sol";
import {BaccaratRulesHarness} from "./helpers/BaccaratRulesHarness.sol";

contract BaccaratRulesTest is Test {
    BaccaratRulesHarness internal harness;

    function setUp() public {
        harness = new BaccaratRulesHarness();
    }

    function test_PlayerDrawRuleMatchesClassicTableau() public view {
        for (uint8 total = 0; total <= 5; total++) {
            assertTrue(harness.playerDraws(total), "player should draw");
        }

        for (uint8 total = 6; total <= 9; total++) {
            assertFalse(harness.playerDraws(total), "player should stand");
        }
    }

    function test_BankerDrawRuleMatchesClassicTableau() public view {
        assertTrue(harness.bankerDraws(0, false, 0));
        assertTrue(harness.bankerDraws(5, false, 0));
        assertFalse(harness.bankerDraws(6, false, 0));

        assertTrue(harness.bankerDraws(2, true, 8));
        assertTrue(harness.bankerDraws(3, true, 7));
        assertFalse(harness.bankerDraws(3, true, 8));
        assertTrue(harness.bankerDraws(4, true, 2));
        assertFalse(harness.bankerDraws(4, true, 1));
        assertTrue(harness.bankerDraws(5, true, 4));
        assertFalse(harness.bankerDraws(5, true, 3));
        assertTrue(harness.bankerDraws(6, true, 6));
        assertFalse(harness.bankerDraws(6, true, 5));
        assertFalse(harness.bankerDraws(7, true, 7));
    }

    function test_ResolveIsDeterministicAndProducesValidFreshShoeRound() public view {
        (
            BaccaratTypes.BaccaratOutcome outcomeA,
            bool naturalA,
            uint8 playerCardCountA,
            uint8 bankerCardCountA,
            uint8 playerTotalA,
            uint8 bankerTotalA
        ) = harness.resolve(123456789);
        (
            BaccaratTypes.BaccaratOutcome outcomeB,
            bool naturalB,
            uint8 playerCardCountB,
            uint8 bankerCardCountB,
            uint8 playerTotalB,
            uint8 bankerTotalB
        ) = harness.resolve(123456789);

        assertEq(uint256(outcomeA), uint256(outcomeB));
        assertEq(playerTotalA, playerTotalB);
        assertEq(bankerTotalA, bankerTotalB);
        assertEq(playerCardCountA, playerCardCountB);
        assertEq(bankerCardCountA, bankerCardCountB);
        assertEq(naturalA, naturalB);
        assertGe(playerCardCountA, 2);
        assertLe(playerCardCountA, 3);
        assertGe(bankerCardCountA, 2);
        assertLe(bankerCardCountA, 3);
    }

    function test_NaturalRoundStopsAfterInitialFourCards() public view {
        bool found = false;
        for (uint256 seed = 1; seed < 10_000; seed++) {
            (, bool natural, uint8 playerCardCount, uint8 bankerCardCount,,) = harness.resolve(seed);
            if (natural) {
                found = true;
                assertEq(playerCardCount, 2);
                assertEq(bankerCardCount, 2);
                break;
            }
        }
        assertTrue(found, "expected natural round");
    }

    function test_CompareTotalsMatchesExpectedOutcome() public view {
        assertEq(uint256(harness.compareTotals(9, 1)), uint256(BaccaratTypes.BaccaratOutcome.PlayerWin));
        assertEq(uint256(harness.compareTotals(2, 7)), uint256(BaccaratTypes.BaccaratOutcome.BankerWin));
        assertEq(uint256(harness.compareTotals(6, 6)), uint256(BaccaratTypes.BaccaratOutcome.Tie));
    }
}
