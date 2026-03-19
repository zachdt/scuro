// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { DeveloperRewards } from "../../src/DeveloperRewards.sol";
import { GameCatalog } from "../../src/GameCatalog.sol";
import { BaseE2ETest } from "./BaseE2E.t.sol";

contract AbusePathsE2ETest is BaseE2ETest {
    function test_NumberPickerRejectsInvalidSelectionZeroWagerAndMissingApproval() public {
        _approveSettlement(player1, 100 ether);

        vm.prank(player1.addr);
        vm.expectRevert("NumberPicker: invalid selection");
        numberPickerAdapter.play(100 ether, 0, keccak256("bad-selection"), numberPickerExpressionTokenId);

        vm.prank(player1.addr);
        vm.expectRevert("NumberPicker: invalid wager");
        numberPickerAdapter.play(0, 25, keccak256("bad-wager"), numberPickerExpressionTokenId);

        vm.prank(player2.addr);
        vm.expectRevert();
        numberPickerAdapter.play(100 ether, 25, keccak256("missing-approval"), numberPickerExpressionTokenId);
    }

    function test_NumberPickerRejectsRetiredModuleAndDuplicateFinalize() public {
        _approveSettlement(player1, 100 ether);

        catalog.setModuleStatus(numberPickerModuleId, GameCatalog.ModuleStatus.RETIRED);
        vm.prank(player1.addr);
        vm.expectRevert("NumberPickerAdapter: module inactive");
        numberPickerAdapter.play(100 ether, 25, keccak256("inactive-engine"), numberPickerExpressionTokenId);

        catalog.setModuleStatus(numberPickerModuleId, GameCatalog.ModuleStatus.LIVE);

        vm.prank(player1.addr);
        uint256 requestId = delayedNumberPickerAdapter.playWithoutFinalize(
            100 ether, 25, keccak256("pending-request"), delayedNumberPickerExpressionTokenId
        );

        vm.expectRevert("NumberPickerAdapter: pending");
        delayedNumberPickerAdapter.finalizeForTest(requestId);

        manualVrfCoordinator.fulfillRequestWithWord(requestId, 77);
        delayedNumberPickerAdapter.finalizeForTest(requestId);

        vm.expectRevert("NumberPickerAdapter: settled");
        delayedNumberPickerAdapter.finalizeForTest(requestId);
    }

    function test_SlotRejectsInactivePresetPendingFinalizeAndDuplicateSettlement() public {
        _approveSettlement(player1, 300 ether);

        delayedSlotMachineEngine.setPresetActive(1, false);
        vm.prank(player1.addr);
        vm.expectRevert("SlotMachine: inactive preset");
        delayedSlotMachineController.spinWithoutFinalize(
            100 ether, 1, keccak256("slot-inactive"), delayedSlotMachineExpressionTokenId
        );

        delayedSlotMachineEngine.setPresetActive(1, true);
        vm.prank(player1.addr);
        uint256 spinId = delayedSlotMachineController.spinWithoutFinalize(
            100 ether, 1, keccak256("slot-pending"), delayedSlotMachineExpressionTokenId
        );

        vm.expectRevert("SlotMachineController: pending");
        delayedSlotMachineController.finalizeForTest(spinId);

        manualVrfCoordinator.fulfillRequestWithWord(spinId, 4);
        delayedSlotMachineController.finalizeForTest(spinId);

        vm.expectRevert("SlotMachineController: settled");
        delayedSlotMachineController.finalizeForTest(spinId);
    }

    function test_SlotLifecycleAllowsRetiredSettlementButRejectsNewLaunchesAndDisabledProgress() public {
        _approveSettlement(player1, 300 ether);

        vm.prank(player1.addr);
        uint256 retiredSpinId = delayedSlotMachineController.spinWithoutFinalize(
            100 ether, 1, keccak256("slot-retired"), delayedSlotMachineExpressionTokenId
        );

        catalog.setModuleStatus(delayedSlotMachineModuleId, GameCatalog.ModuleStatus.RETIRED);
        vm.prank(player1.addr);
        vm.expectRevert("SlotMachineController: module inactive");
        delayedSlotMachineController.spinWithoutFinalize(
            100 ether, 1, keccak256("slot-retired-launch"), delayedSlotMachineExpressionTokenId
        );

        manualVrfCoordinator.fulfillRequestWithWord(retiredSpinId, 4);
        delayedSlotMachineController.finalizeForTest(retiredSpinId);

        catalog.setModuleStatus(delayedSlotMachineModuleId, GameCatalog.ModuleStatus.LIVE);
        vm.prank(player1.addr);
        uint256 disabledSpinId = delayedSlotMachineController.spinWithoutFinalize(
            100 ether, 1, keccak256("slot-disabled"), delayedSlotMachineExpressionTokenId
        );

        catalog.setModuleStatus(delayedSlotMachineModuleId, GameCatalog.ModuleStatus.DISABLED);
        vm.expectRevert("ManualVRF: callback failed");
        manualVrfCoordinator.fulfillRequestWithWord(disabledSpinId, 4);
        vm.expectRevert("SlotMachineController: module inactive");
        delayedSlotMachineController.finalizeForTest(disabledSpinId);
    }

    function test_TournamentAndPvPRespectRetiredAndDisabledModules() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        (uint256 tournamentId, uint256 gameId) = _createTournament(10 ether, 20 ether, 1_000);
        vm.expectRevert("TournamentController: game active");
        tournamentController.reportOutcome(gameId);

        catalog.setModuleStatus(tournamentPokerModuleId, GameCatalog.ModuleStatus.RETIRED);
        vm.expectRevert("TournamentController: module inactive");
        tournamentController.createTournament(10 ether, 20 ether, 1_000, pokerExpressionTokenId);
        vm.expectRevert("TournamentController: module inactive");
        tournamentController.startGameForPlayers(tournamentId, player1.addr, player2.addr);

        catalog.setModuleStatus(pvpPokerModuleId, GameCatalog.ModuleStatus.RETIRED);
        vm.expectRevert("PvPController: module inactive");
        _createPvPSession(10 ether, 20 ether, 1_000);

        _playTournamentAllInSingleDraw(gameId, player1.addr);
        tournamentController.reportOutcome(gameId);
        _assertPlayerBalances(10_010 ether, 9_990 ether);

        catalog.setModuleStatus(pvpPokerModuleId, GameCatalog.ModuleStatus.LIVE);
        uint256 sessionId = _createPvPSession(10 ether, 20 ether, 1_000);
        _playPvPAllInSingleDraw(sessionId, player1.addr);
        catalog.setModuleStatus(pvpPokerModuleId, GameCatalog.ModuleStatus.DISABLED);
        vm.expectRevert("PvPController: module inactive");
        pvpController.settleSession(sessionId);

        catalog.setModuleStatus(pvpPokerModuleId, GameCatalog.ModuleStatus.LIVE);
        pvpController.settleSession(sessionId);
        _assertPlayerBalances(10_020 ether, 9_980 ether);
    }

    function test_PokerEngineRejectsUnauthorizedGameInitialization() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        vm.prank(outsider.addr);
        vm.expectRevert("SingleDraw: not controller");
        tournamentPokerEngine.initializeGame(1, players, stacks, 0, 20 ether);
    }

    function test_DeveloperRewardsRejectEarlyCloseClaimBeforeCloseDuplicateClaimAndZeroAccrualMint() public {
        _approveSettlement(player1, 100 ether);
        vm.prank(player1.addr);
        numberPickerAdapter.play(100 ether, 25, keccak256("claim-guard"), numberPickerExpressionTokenId);

        vm.expectRevert("DeveloperRewards: epoch active");
        developerRewards.closeCurrentEpoch();

        uint256[] memory epochs = new uint256[](1);
        epochs[0] = 1;
        vm.prank(soloDeveloper.addr);
        vm.expectRevert("DeveloperRewards: epoch open");
        developerRewards.claim(epochs);

        _closeEpoch();

        uint256 outsiderBalanceBefore = token.balanceOf(outsider.addr);
        vm.prank(outsider.addr);
        developerRewards.claim(epochs);
        assertEq(token.balanceOf(outsider.addr), outsiderBalanceBefore);

        vm.prank(soloDeveloper.addr);
        developerRewards.claim(epochs);

        vm.prank(soloDeveloper.addr);
        vm.expectRevert("DeveloperRewards: already claimed");
        developerRewards.claim(epochs);
    }

    function test_GovernanceRejectsInsufficientVotesAndEnforcesTimelockDelay() public {
        address[] memory targets = new address[](1);
        targets[0] = address(developerRewards);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(DeveloperRewards.setEpochDuration, (3 days));

        vm.prank(outsider.addr);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "insufficient-votes");

        _stakeAndDelegate(player1, STAKE_AMOUNT);
        vm.roll(block.number + 1);

        vm.prank(player1.addr);
        uint256 proposalId = governor.propose(targets, values, calldatas, "timelock-delay");

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(player1.addr);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        bytes32 descriptionHash = keccak256(bytes("timelock-delay"));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.expectRevert();
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    function test_PokerRejectsDrawProofsOutsideDrawPhase() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        uint256 invalidPhaseGameId = 700;
        vm.prank(address(tournamentController));
        tournamentPokerEngine.initializeGame(invalidPhaseGameId, players, stacks, 0, 20 ether);

        PokerDrawFixture memory player0Draw = _loadPokerDrawFixture("poker_draw_resolve");
        vm.expectRevert("SingleDraw: no draw");
        tournamentPokerEngine.submitDrawProof(
            invalidPhaseGameId,
            player1.addr,
            player0Draw.newCommitment,
            player0Draw.newEncryptionKeyCommitment,
            player0Draw.newCiphertextRef,
            player0Draw.proof
        );
    }

    function test_PokerRejectsInvalidDrawAndShowdownProofs() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        vm.prank(address(tournamentController));
        tournamentPokerEngine.initializeGame(1, players, stacks, 0, 20 ether);
        _submitPokerInitialDealProof(tournamentPokerEngine, 1);

        vm.prank(player1.addr);
        tournamentPokerEngine.bet(1, 10);
        vm.prank(player2.addr);
        tournamentPokerEngine.bet(1, 0);

        uint8[] memory empty = new uint8[](0);
        vm.prank(player2.addr);
        tournamentPokerEngine.declareDraw(1, empty);
        vm.prank(player1.addr);
        tournamentPokerEngine.declareDraw(1, empty);

        PokerDrawFixture memory player0Draw = _loadPokerDrawFixture("poker_draw_resolve");
        vm.expectRevert("SingleDraw: invalid draw proof");
        tournamentPokerEngine.submitDrawProof(
            1,
            player1.addr,
            bytes32(uint256(player0Draw.newCommitment) + 1),
            player0Draw.newEncryptionKeyCommitment,
            player0Draw.newCiphertextRef,
            player0Draw.proof
        );

        PokerDrawFixture memory player1Draw = _loadPokerDrawFixture("poker_draw_resolve_player1");
        tournamentPokerEngine.submitDrawProof(
            1,
            player1.addr,
            player0Draw.newCommitment,
            player0Draw.newEncryptionKeyCommitment,
            player0Draw.newCiphertextRef,
            player0Draw.proof
        );
        tournamentPokerEngine.submitDrawProof(
            1,
            player2.addr,
            player1Draw.newCommitment,
            player1Draw.newEncryptionKeyCommitment,
            player1Draw.newCiphertextRef,
            player1Draw.proof
        );

        vm.prank(player2.addr);
        tournamentPokerEngine.bet(1, 0);
        vm.prank(player1.addr);
        tournamentPokerEngine.bet(1, 0);

        PokerShowdownFixture memory showdown = _loadPokerShowdownFixture("poker_showdown");
        vm.expectRevert("SingleDraw: invalid showdown");
        tournamentPokerEngine.submitShowdownProof(1, player2.addr, showdown.isTie, showdown.proof);
    }

    function test_PokerTimeoutClaimsTheCurrentHand() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        vm.prank(address(tournamentController));
        tournamentPokerEngine.initializeGame(1, players, stacks, 0, 20 ether);
        _submitPokerInitialDealProof(tournamentPokerEngine, 1);
        vm.expectRevert("SingleDraw: active");
        tournamentPokerEngine.claimTimeout(1);

        vm.warp(block.timestamp + 61);
        tournamentPokerEngine.claimTimeout(1);
        assertFalse(tournamentPokerEngine.isGameOver(1));
    }

    function test_PokerFoldEndsTheCurrentHand() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        vm.prank(address(tournamentController));
        tournamentPokerEngine.initializeGame(1, players, stacks, 0, 20 ether);
        _submitPokerInitialDealProof(tournamentPokerEngine, 1);
        vm.prank(player1.addr);
        tournamentPokerEngine.fold(1);
        assertFalse(tournamentPokerEngine.isGameOver(1));
    }

    function test_PokerTieProofAdvancesToNextHand() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        vm.prank(address(tournamentController));
        tournamentPokerEngine.initializeGame(1, players, stacks, 0, 20 ether);
        _advanceToShowdown(tournamentPokerEngine, 1);
        _submitPokerTieShowdown(tournamentPokerEngine, 1);
        assertFalse(tournamentPokerEngine.isGameOver(1));
        assertEq(tournamentPokerEngine.getHandState(1).handNumber, 2);
    }

    function test_CatalogAndSettlementRejectUnauthorizedCallers() public {
        vm.prank(outsider.addr);
        vm.expectRevert();
        catalog.registerModule(
            GameCatalog.Module({
                mode: GameCatalog.GameMode.Solo,
                controller: outsider.addr,
                engine: address(0x1234),
                engineType: keccak256("fake"),
                verifier: address(0),
                configHash: bytes32(0),
                developerRewardBps: 100,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        vm.prank(outsider.addr);
        vm.expectRevert();
        catalog.setModuleStatus(numberPickerModuleId, GameCatalog.ModuleStatus.DISABLED);

        vm.prank(outsider.addr);
        vm.expectRevert("Settlement: unauthorized controller");
        settlement.burnPlayerWager(player1.addr, 1 ether);

        vm.prank(outsider.addr);
        vm.expectRevert("Settlement: unauthorized controller");
        settlement.mintPlayerReward(player1.addr, 1 ether);

        vm.prank(outsider.addr);
        vm.expectRevert("Settlement: unauthorized controller");
        settlement.accrueDeveloperForExpression(numberPickerExpressionTokenId, 1 ether);
    }

    function test_SettlementRejectsInactiveOrMismatchedExpressions() public {
        _approveSettlement(player1, 300 ether);

        vm.prank(player1.addr);
        numberPickerAdapter.play(100 ether, 25, keccak256("active-expression"), numberPickerExpressionTokenId);

        expressionRegistry.setExpressionActive(numberPickerExpressionTokenId, false);
        vm.prank(player1.addr);
        vm.expectRevert("Settlement: expression inactive");
        numberPickerAdapter.play(100 ether, 25, keccak256("inactive-expression"), numberPickerExpressionTokenId);

        expressionRegistry.setExpressionActive(numberPickerExpressionTokenId, true);
        vm.prank(player1.addr);
        vm.expectRevert("Settlement: expression mismatch");
        numberPickerAdapter.play(100 ether, 25, keccak256("wrong-type"), pokerExpressionTokenId);
    }
}
