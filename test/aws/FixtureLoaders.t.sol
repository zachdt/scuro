// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FixtureLoadersHarness} from "./FixtureLoadersHarness.sol";

contract FixtureLoadersTest is Test {
    FixtureLoadersHarness internal harness;

    function setUp() public {
        harness = new FixtureLoadersHarness();
    }

    function test_LoadPokerInitialDealFixture() public view {
        FixtureLoadersHarness.PokerInitialDealFixture memory fixture = harness.loadPokerInitialDeal();
        assertTrue(fixture.proof.length > 0, "proof missing");
        assertTrue(fixture.deckCommitment != bytes32(0), "deck commitment missing");
        assertTrue(fixture.handCommitments[0] != bytes32(0), "hand commitment missing");
    }

    function test_LoadPokerShowdownFixture() public view {
        FixtureLoadersHarness.PokerShowdownFixture memory fixture = harness.loadPokerShowdown();
        assertTrue(fixture.proof.length > 0, "proof missing");
        assertFalse(fixture.isTie, "fixture should be decisive");
    }

    function test_LoadBlackjackFixtures() public view {
        FixtureLoadersHarness.BlackjackInitialDealFixture memory initialDeal = harness.loadBlackjackInitialDeal();
        FixtureLoadersHarness.BlackjackActionFixture memory actionFixture = harness.loadBlackjackAction();

        assertTrue(initialDeal.proof.length > 0, "initial proof missing");
        assertTrue(initialDeal.playerKeyCommitment != bytes32(0), "player key commitment missing");
        assertTrue(actionFixture.proof.length > 0, "action proof missing");
        assertTrue(actionFixture.newPlayerStateCommitment != bytes32(0), "new state commitment missing");
    }
}
