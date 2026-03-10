// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperRewards} from "../../src/DeveloperRewards.sol";
import {BaseE2ETest} from "./BaseE2E.t.sol";

contract SmokeE2ETest is BaseE2ETest {
    function test_WiringAndCatalogBootstrap() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(settlement)));
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(developerRewards)));
        assertTrue(developerRewards.hasRole(developerRewards.SETTLEMENT_ROLE(), address(settlement)));
        assertTrue(catalog.isLaunchableController(address(tournamentController)));
        assertTrue(catalog.isLaunchableController(address(pvpController)));
        assertTrue(catalog.isLaunchableController(address(numberPickerAdapter)));
        assertTrue(catalog.isLaunchableController(address(blackjackController)));
        assertTrue(catalog.isAuthorizedControllerForEngine(address(numberPickerAdapter), address(numberPickerEngine)));
        assertTrue(catalog.isAuthorizedControllerForEngine(address(tournamentController), address(tournamentPokerEngine)));
        assertTrue(catalog.isAuthorizedControllerForEngine(address(pvpController), address(pvpPokerEngine)));
        assertTrue(catalog.isAuthorizedControllerForEngine(address(blackjackController), address(blackjackEngine)));
        assertEq(expressionRegistry.ownerOf(numberPickerExpressionTokenId), soloDeveloper.addr);
        assertEq(expressionRegistry.ownerOf(pokerExpressionTokenId), pokerDeveloper.addr);
        assertEq(expressionRegistry.ownerOf(blackjackExpressionTokenId), soloDeveloper.addr);
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
    }

    function test_MinimalGovernanceFlow() public {
        _executeGovernanceProposal(
            address(developerRewards),
            abi.encodeCall(DeveloperRewards.setEpochDuration, (14 days)),
            "smoke-update-epoch-duration"
        );
        assertEq(developerRewards.epochDuration(), 14 days);
    }

    function test_MinimalSoloPlayFlow() public {
        _approveSettlement(player1, 100 ether);
        vm.prank(player1.addr);
        uint256 requestId =
            numberPickerAdapter.play(100 ether, 25, keccak256("smoke-solo"), numberPickerExpressionTokenId);

        (, uint256 wager, , , , , bool fulfilled) = numberPickerEngine.getOutcome(requestId);
        assertTrue(fulfilled);
        assertEq(wager, 100 ether);
        _assertDeveloperAccrual(soloDeveloper.addr, 1, 5 ether);
        assertTrue(numberPickerAdapter.requestSettled(requestId));
        assertEq(numberPickerAdapter.requestExpressionTokenId(requestId), numberPickerExpressionTokenId);
    }

    function test_MinimalTournamentFlow() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        (uint256 tournamentId, uint256 gameId) = _createTournament(10 ether, 20 ether, 1_000);
        _playTournamentAllInSingleDraw(gameId, player1.addr);
        tournamentController.reportOutcome(gameId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertDeveloperAccrual(pokerDeveloper.addr, 1, 4 ether);
        (, , , , uint256 expressionTokenId) = tournamentController.tournaments(tournamentId);
        assertEq(expressionTokenId, pokerExpressionTokenId);
    }

    function test_MinimalPvPFlow() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        uint256 sessionId = _createPvPSession(10 ether, 20 ether, 1_000);
        _playPvPAllInSingleDraw(sessionId, player1.addr);
        pvpController.settleSession(sessionId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertDeveloperAccrual(pokerDeveloper.addr, 1, 4 ether);
        (, , , , , , uint256 expressionTokenId) = pvpController.sessions(sessionId);
        assertEq(expressionTokenId, pokerExpressionTokenId);
    }
}
