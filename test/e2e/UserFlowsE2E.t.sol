// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperRewards} from "../../src/DeveloperRewards.sol";
import {BaseE2ETest} from "./BaseE2E.t.sol";

contract UserFlowsE2ETest is BaseE2ETest {
    function test_SoloFlow_EndToEnd() public {
        uint256 developerBalanceBefore = token.balanceOf(soloDeveloper.addr);
        _approveSettlement(player1, 100 ether);

        vm.prank(player1.addr);
        uint256 requestId =
            numberPickerAdapter.play(100 ether, 25, keccak256("solo-flow"), numberPickerExpressionTokenId);
        (, , , , uint256 payout, , ) = numberPickerEngine.getOutcome(requestId);

        _closeEpoch();

        uint256[] memory epochs = new uint256[](1);
        epochs[0] = 1;
        vm.prank(soloDeveloper.addr);
        developerRewards.claim(epochs);

        assertEq(token.balanceOf(player1.addr), PLAYER_FUNDS - 100 ether + payout);
        assertEq(token.balanceOf(soloDeveloper.addr), developerBalanceBefore + 5 ether);
    }

    function test_SoloMultiPlay_AggregatesActivityWithinEpoch() public {
        _approveSettlement(player1, 1_000 ether);
        _approveSettlement(player2, 1_000 ether);

        vm.prank(player1.addr);
        uint256 requestId1 = numberPickerAdapter.play(50 ether, 20, keccak256("solo-1"), numberPickerExpressionTokenId);
        vm.prank(player2.addr);
        uint256 requestId2 =
            numberPickerAdapter.play(150 ether, 30, keccak256("solo-2"), numberPickerExpressionTokenId);

        (, , , , uint256 payout1, , ) = numberPickerEngine.getOutcome(requestId1);
        (, , , , uint256 payout2, , ) = numberPickerEngine.getOutcome(requestId2);

        assertEq(token.balanceOf(player1.addr), PLAYER_FUNDS - 50 ether + payout1);
        assertEq(token.balanceOf(player2.addr), PLAYER_FUNDS - 150 ether + payout2);
        _assertDeveloperAccrual(soloDeveloper.addr, 1, 10 ether);
    }

    function test_TransferredExpressionRedirectsOnlyFutureAccruals() public {
        _approveSettlement(player1, 300 ether);

        vm.prank(player1.addr);
        numberPickerAdapter.play(100 ether, 20, keccak256("before-transfer"), numberPickerExpressionTokenId);
        _assertDeveloperAccrual(soloDeveloper.addr, 1, 5 ether);
        _assertDeveloperAccrual(outsider.addr, 1, 0);

        vm.prank(soloDeveloper.addr);
        expressionRegistry.transferFrom(soloDeveloper.addr, outsider.addr, numberPickerExpressionTokenId);

        vm.prank(player1.addr);
        numberPickerAdapter.play(200 ether, 20, keccak256("after-transfer"), numberPickerExpressionTokenId);

        _assertDeveloperAccrual(soloDeveloper.addr, 1, 5 ether);
        _assertDeveloperAccrual(outsider.addr, 1, 10 ether);
    }

    function test_TournamentFlow_EndToEnd() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        (, uint256 gameId) = _createTournament(10 ether, 20 ether, 1_000);
        _playTournamentAllInSingleDraw(gameId, player1.addr);
        tournamentController.reportOutcome(gameId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertDeveloperAccrual(pokerDeveloper.addr, 1, 4 ether);

        vm.expectRevert("TournamentController: reported");
        tournamentController.reportOutcome(gameId);
    }

    function test_PvPFlow_EndToEnd() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        uint256 sessionId = _createPvPSession(10 ether, 20 ether, 1_000);
        _playPvPAllInSingleDraw(sessionId, player1.addr);
        pvpController.settleSession(sessionId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertDeveloperAccrual(pokerDeveloper.addr, 1, 4 ether);

        vm.expectRevert("PvPController: settled");
        pvpController.settleSession(sessionId);
    }

    function test_GovernanceFlow_ChangesEpochDurationAndBehavior() public {
        _approveSettlement(player1, 100 ether);
        vm.prank(player1.addr);
        numberPickerAdapter.play(100 ether, 25, keccak256("governed-play"), numberPickerExpressionTokenId);

        _executeGovernanceProposal(
            address(developerRewards),
            abi.encodeCall(DeveloperRewards.setEpochDuration, (1 days)),
            "governance-update-epoch-duration"
        );

        vm.warp(block.timestamp + 1 days + 1);
        developerRewards.closeCurrentEpoch();
        assertTrue(developerRewards.epochClosed(1));
    }

    function test_MultiEpochFlow_ClosedEpochsRemainClaimableLater() public {
        uint256 developerBalanceBefore = token.balanceOf(soloDeveloper.addr);
        _approveSettlement(player1, 1_000 ether);

        vm.prank(player1.addr);
        numberPickerAdapter.play(100 ether, 20, keccak256("epoch-1"), numberPickerExpressionTokenId);
        _closeEpoch();

        vm.prank(player1.addr);
        numberPickerAdapter.play(200 ether, 20, keccak256("epoch-2"), numberPickerExpressionTokenId);
        _closeEpoch();

        uint256[] memory epochs = new uint256[](2);
        epochs[0] = 1;
        epochs[1] = 2;
        vm.prank(soloDeveloper.addr);
        developerRewards.claim(epochs);

        assertEq(developerRewards.currentEpoch(), 3);
        assertEq(token.balanceOf(soloDeveloper.addr), developerBalanceBefore + 15 ether);
    }
}
