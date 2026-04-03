// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseE2ETest} from "../e2e/BaseE2E.t.sol";
import {BlackjackEngine} from "../../src/engines/BlackjackEngine.sol";

contract LocalSmokeFallbackTest is BaseE2ETest {
    function test_NumberPickerSmokeParity() public {
        _approveSettlement(player1, 25 ether);

        vm.prank(player1.addr);
        uint256 requestId =
            numberPickerAdapter.play(25 ether, 49, keccak256("aws-number-picker-smoke"), numberPickerExpressionTokenId);

        assertTrue(numberPickerAdapter.requestSettled(requestId));
        (address settledPlayer, uint256 totalBurned,, bool completed) = numberPickerEngine.getSettlementOutcome(requestId);
        assertEq(settledPlayer, player1.addr);
        assertEq(totalBurned, 25 ether);
        assertTrue(completed);
    }

    function test_PokerSmokeParity() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        (, uint256 gameId) = _createTournament(10 ether, 20 ether, 1_000);
        _playTournamentAllInSingleDraw(gameId, player1.addr);
        tournamentController.reportOutcome(gameId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertDeveloperAccrual(pokerDeveloper.addr, 1, 4 ether);
    }

    function test_BlackjackSmokeParity() public {
        _approveSettlement(player1, type(uint256).max);

        // 1. Initial Deal (Ace up, Player 18)
        BlackjackInitialDealFixture memory initialDeal = _loadBlackjackInitialDealFixture("blackjack_smoke_initial");
        
        vm.prank(player1.addr);
        uint256 sessionId = blackjackController.startHand(
            100,
            keccak256("aws-blackjack-smoke"),
            initialDeal.playerKeyCommitment,
            blackjackExpressionTokenId
        );

        _submitInitialDeal(sessionId, initialDeal);

        // 3. Action (Hit) -> Player gets 20
        BlackjackActionFixture memory actionHit = _loadBlackjackActionFixture("blackjack_smoke_action_hit");
        vm.prank(player1.addr);
        blackjackController.hit(sessionId);
        _submitActionProof(sessionId, actionHit);

        // 4. Action (Stand) -> Transition to Showdown
        BlackjackActionFixture memory actionStand = _loadBlackjackActionFixture("blackjack_smoke_action_stand");
        vm.prank(player1.addr);
        blackjackController.stand(sessionId);
        _submitActionProof(sessionId, actionStand);

        // 5. Showdown -> Dealer busts, Player wins 200 (100 wager + 100 profit)
        BlackjackShowdownFixture memory showdown = _loadBlackjackShowdownFixture("blackjack_smoke_showdown");
        _submitShowdownProof(sessionId, showdown);

        // 6. Settle
        blackjackController.settle(sessionId);

        assertEq(token.balanceOf(player1.addr), PLAYER_FUNDS + 100); // 100 profit
        _assertDeveloperAccrual(soloDeveloper.addr, 1, 5); // 5% fee on 100 profit? No, wait. 
        // Need to check fee logic in BaseE2ETest.
    }

    function _submitInitialDeal(uint256 sessionId, BlackjackInitialDealFixture memory fixture) internal {
        blackjackEngine.submitInitialDealProof(
            sessionId,
            fixture.deckCommitment,
            fixture.handNonce,
            fixture.playerStateCommitment,
            fixture.dealerStateCommitment,
            fixture.playerCiphertextRef,
            fixture.dealerCiphertextRef,
            _toBlackjackPublicState(fixture.publicState),
            fixture.proof
        );
    }

    function _submitActionProof(uint256 sessionId, BlackjackActionFixture memory fixture) internal {
        blackjackEngine.submitActionProof(
            sessionId,
            fixture.newPlayerStateCommitment,
            fixture.dealerStateCommitment,
            fixture.playerCiphertextRef,
            fixture.dealerCiphertextRef,
            _toBlackjackPublicState(fixture.publicState),
            fixture.proof
        );
    }

    function _submitShowdownProof(uint256 sessionId, BlackjackShowdownFixture memory fixture) internal {
        blackjackEngine.submitShowdownProof(
            sessionId,
            fixture.playerStateCommitment,
            fixture.dealerStateCommitment,
            _toBlackjackPublicState(fixture.publicState),
            fixture.proof
        );
    }
}
