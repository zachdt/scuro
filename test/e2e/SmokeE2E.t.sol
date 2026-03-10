// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseE2ETest} from "./BaseE2E.t.sol";
import {CreatorRewards} from "../../src/CreatorRewards.sol";

contract SmokeE2ETest is BaseE2ETest {
    function test_WiringAndRegistryBootstrap() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(settlement)));
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(creatorRewards)));
        assertTrue(creatorRewards.hasRole(creatorRewards.SETTLEMENT_ROLE(), address(settlement)));
        assertTrue(settlement.hasRole(settlement.CONTROLLER_ROLE(), address(tournamentController)));
        assertTrue(settlement.hasRole(settlement.CONTROLLER_ROLE(), address(pvpController)));
        assertTrue(settlement.hasRole(settlement.CONTROLLER_ROLE(), address(numberPickerAdapter)));
        assertTrue(settlement.hasRole(settlement.CONTROLLER_ROLE(), address(blackjackController)));
        assertTrue(numberPickerEngine.hasRole(numberPickerEngine.ADAPTER_ROLE(), address(numberPickerAdapter)));
        assertTrue(blackjackEngine.hasRole(blackjackEngine.CONTROLLER_ROLE(), address(blackjackController)));
        assertTrue(registry.isRegisteredForSolo(address(numberPickerEngine)));
        assertTrue(registry.isRegisteredForSolo(address(blackjackEngine)));
        assertTrue(registry.isRegisteredForTournament(address(pokerEngine)));
        assertTrue(registry.isRegisteredForPvP(address(pokerEngine)));
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
    }

    function test_MinimalGovernanceFlow() public {
        _executeGovernanceProposal(
            address(creatorRewards),
            abi.encodeCall(CreatorRewards.setEpochDuration, (14 days)),
            "smoke-update-epoch-duration"
        );
        assertEq(creatorRewards.epochDuration(), 14 days);
    }

    function test_MinimalSoloPlayFlow() public {
        _approveSettlement(player1, 100 ether);
        vm.prank(player1.addr);
        uint256 requestId = numberPickerAdapter.play(100 ether, 25, keccak256("smoke-solo"));

        (, uint256 wager, , , , , bool fulfilled) = numberPickerEngine.getOutcome(requestId);
        assertTrue(fulfilled);
        assertEq(wager, 100 ether);
        _assertCreatorAccrual(soloCreator.addr, 1, 5 ether);
        assertTrue(numberPickerAdapter.requestSettled(requestId));
    }

    function test_MinimalTournamentFlow() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        (, uint256 gameId) = _createTournament(10 ether, 20 ether, 1_000);
        _playAllInSingleDraw(gameId, player1.addr);
        tournamentController.reportOutcome(gameId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertCreatorAccrual(pokerCreator.addr, 1, 4 ether);
    }

    function test_MinimalPvPFlow() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        uint256 sessionId = _createPvPSession(10 ether, 20 ether, 1_000);
        _playAllInSingleDraw(sessionId, player1.addr);
        pvpController.settleSession(sessionId);

        _assertPlayerBalances(10_010 ether, 9_990 ether);
        _assertCreatorAccrual(pokerCreator.addr, 1, 4 ether);
    }
}
