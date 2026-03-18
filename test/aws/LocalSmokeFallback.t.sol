// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseE2ETest} from "../e2e/BaseE2E.t.sol";

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

        BlackjackInitialDealFixture memory initialDeal = _loadBlackjackInitialDealFixture();
        BlackjackActionFixture memory actionFixture = _loadBlackjackActionFixture();
        BlackjackShowdownFixture memory showdownFixture = _loadBlackjackShowdownFixture();

        vm.prank(player1.addr);
        uint256 sessionId = blackjackController.startHand(
            100,
            keccak256("aws-blackjack-smoke"),
            initialDeal.playerKeyCommitment,
            blackjackExpressionTokenId
        );

        _submitInitialDeal(sessionId, initialDeal);

        vm.prank(player1.addr);
        blackjackController.hit(sessionId);
        _submitActionProof(sessionId, actionFixture);

        vm.prank(player1.addr);
        blackjackController.stand(sessionId);
        _submitShowdownProof(sessionId, showdownFixture);

        blackjackController.settle(sessionId);

        assertEq(token.balanceOf(player1.addr), PLAYER_FUNDS + 100);
        _assertDeveloperAccrual(soloDeveloper.addr, 1, 5);
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
            fixture.dealerVisibleValue,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.payout,
            fixture.immediateResultCode,
            fixture.handValues,
            fixture.handStatuses,
            fixture.allowedActionMasks,
            fixture.softMask,
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
            fixture.dealerVisibleValue,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.nextPhase,
            fixture.handValues,
            fixture.handStatuses,
            fixture.allowedActionMasks,
            fixture.softMask,
            fixture.proof
        );
    }

    function _submitShowdownProof(uint256 sessionId, BlackjackShowdownFixture memory fixture) internal {
        blackjackEngine.submitShowdownProof(
            sessionId,
            fixture.playerStateCommitment,
            fixture.dealerStateCommitment,
            fixture.payout,
            fixture.dealerFinalValue,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.handStatuses,
            fixture.proof
        );
    }
}
