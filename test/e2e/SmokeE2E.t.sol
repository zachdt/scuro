// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperRewards} from "../../src/DeveloperRewards.sol";
import {BaseE2ETest} from "./BaseE2E.t.sol";

contract SmokeE2ETest is BaseE2ETest {
    function test_WiringAndRegistryBootstrap() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(settlement)));
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(developerRewards)));
        assertTrue(developerRewards.hasRole(developerRewards.SETTLEMENT_ROLE(), address(settlement)));
        assertTrue(settlement.hasRole(settlement.CONTROLLER_ROLE(), address(tournamentController)));
        assertTrue(settlement.hasRole(settlement.CONTROLLER_ROLE(), address(pvpController)));
        assertTrue(settlement.hasRole(settlement.CONTROLLER_ROLE(), address(numberPickerAdapter)));
        assertTrue(settlement.hasRole(settlement.CONTROLLER_ROLE(), address(blackjackController)));
        assertTrue(numberPickerEngine.hasRole(numberPickerEngine.ADAPTER_ROLE(), address(numberPickerAdapter)));
        assertTrue(pokerEngine.hasRole(pokerEngine.CONTROLLER_ROLE(), address(tournamentController)));
        assertTrue(pokerEngine.hasRole(pokerEngine.CONTROLLER_ROLE(), address(pvpController)));
        assertTrue(blackjackEngine.hasRole(blackjackEngine.CONTROLLER_ROLE(), address(blackjackController)));
        assertTrue(registry.isRegisteredForSolo(address(numberPickerEngine)));
        assertTrue(registry.isRegisteredForSolo(address(blackjackEngine)));
        assertTrue(registry.isRegisteredForTournament(address(pokerEngine)));
        assertTrue(registry.isRegisteredForPvP(address(pokerEngine)));
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
        _playAllInSingleDraw(gameId, player1.addr);
        tournamentController.reportOutcome(gameId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertDeveloperAccrual(pokerDeveloper.addr, 1, 4 ether);
        (, , , , , uint256 expressionTokenId, ) = tournamentController.tournaments(tournamentId);
        assertEq(expressionTokenId, pokerExpressionTokenId);
    }

    function test_MinimalPvPFlow() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        uint256 sessionId = _createPvPSession(10 ether, 20 ether, 1_000);
        _playAllInSingleDraw(sessionId, player1.addr);
        pvpController.settleSession(sessionId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertDeveloperAccrual(pokerDeveloper.addr, 1, 4 ether);
        (, , , , , , , uint256 expressionTokenId, bytes memory engineConfig) = pvpController.sessions(sessionId);
        engineConfig;
        assertEq(expressionTokenId, pokerExpressionTokenId);
    }
}
