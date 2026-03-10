// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseE2ETest} from "./BaseE2E.t.sol";
import {CreatorRewards} from "../../src/CreatorRewards.sol";
import {GameEngineRegistry} from "../../src/GameEngineRegistry.sol";

contract AbusePathsE2ETest is BaseE2ETest {
    function test_NumberPickerRejectsInvalidSelectionZeroWagerAndMissingApproval() public {
        _approveSettlement(player1, 100 ether);

        vm.prank(player1.addr);
        vm.expectRevert("NumberPicker: invalid selection");
        numberPickerAdapter.play(100 ether, 0, keccak256("bad-selection"));

        vm.prank(player1.addr);
        vm.expectRevert("NumberPicker: invalid wager");
        numberPickerAdapter.play(0, 25, keccak256("bad-wager"));

        vm.prank(player2.addr);
        vm.expectRevert();
        numberPickerAdapter.play(100 ether, 25, keccak256("missing-approval"));
    }

    function test_NumberPickerRejectsInactiveEngineAndDuplicateFinalize() public {
        _approveSettlement(player1, 100 ether);

        registry.setEngineActive(address(numberPickerEngine), false);
        vm.prank(player1.addr);
        vm.expectRevert("NumberPickerAdapter: engine inactive");
        numberPickerAdapter.play(100 ether, 25, keccak256("inactive-engine"));

        registry.setEngineActive(address(numberPickerEngine), true);

        vm.prank(player1.addr);
        uint256 requestId = delayedNumberPickerAdapter.playWithoutFinalize(100 ether, 25, keccak256("pending-request"));

        vm.expectRevert("NumberPickerAdapter: pending");
        delayedNumberPickerAdapter.finalizeForTest(requestId);

        manualVrfCoordinator.fulfillRequestWithWord(requestId, 77);
        delayedNumberPickerAdapter.finalizeForTest(requestId);

        vm.expectRevert("NumberPickerAdapter: settled");
        delayedNumberPickerAdapter.finalizeForTest(requestId);
    }

    function test_TournamentAndPvPRejectInactiveEnginesPrematureSettlementAndReplay() public {
        _approveSettlement(player1, type(uint256).max);
        _approveSettlement(player2, type(uint256).max);

        (, uint256 gameId) = _createTournament(10 ether, 20 ether, 1_000);
        vm.expectRevert("TournamentController: game active");
        tournamentController.reportOutcome(gameId);

        registry.setEngineActive(address(pokerEngine), false);
        vm.expectRevert("TournamentController: engine inactive");
        tournamentController.createTournament(10 ether, 20 ether, address(pokerEngine), 1_000, _defaultPokerConfig(address(this)));

        vm.expectRevert("PvPController: engine inactive");
        _createPvPSession(10 ether, 20 ether, 1_000);
    }

    function test_CreatorRewardsRejectEarlyCloseClaimBeforeCloseDuplicateClaimAndZeroAccrualMint() public {
        _approveSettlement(player1, 100 ether);
        vm.prank(player1.addr);
        numberPickerAdapter.play(100 ether, 25, keccak256("claim-guard"));

        vm.expectRevert("CreatorRewards: epoch active");
        creatorRewards.closeCurrentEpoch();

        uint256[] memory epochs = new uint256[](1);
        epochs[0] = 1;
        vm.prank(soloCreator.addr);
        vm.expectRevert("CreatorRewards: epoch open");
        creatorRewards.claim(epochs);

        _closeEpoch();

        uint256 outsiderBalanceBefore = token.balanceOf(outsider.addr);
        vm.prank(outsider.addr);
        creatorRewards.claim(epochs);
        assertEq(token.balanceOf(outsider.addr), outsiderBalanceBefore);

        vm.prank(soloCreator.addr);
        creatorRewards.claim(epochs);

        vm.prank(soloCreator.addr);
        vm.expectRevert("CreatorRewards: already claimed");
        creatorRewards.claim(epochs);
    }

    function test_GovernanceRejectsInsufficientVotesAndEnforcesTimelockDelay() public {
        address[] memory targets = new address[](1);
        targets[0] = address(creatorRewards);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(CreatorRewards.setEpochDuration, (3 days));

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
        pokerEngine.initializeGame(invalidPhaseGameId, players, stacks, 0, 20 ether, _defaultPokerConfig(address(this)));

        PokerDrawFixture memory player0Draw = _loadPokerDrawFixture("poker_draw_resolve");
        vm.expectRevert("SingleDraw: no draw");
        pokerEngine.submitDrawProof(
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

        pokerEngine.initializeGame(1, players, stacks, 0, 20 ether, _defaultPokerConfig(address(this)));
        _submitPokerInitialDealProof(1);

        vm.prank(player1.addr);
        pokerEngine.bet(1, 10);
        vm.prank(player2.addr);
        pokerEngine.bet(1, 0);

        uint8[] memory empty = new uint8[](0);
        vm.prank(player2.addr);
        pokerEngine.declareDraw(1, empty);
        vm.prank(player1.addr);
        pokerEngine.declareDraw(1, empty);

        PokerDrawFixture memory player0Draw = _loadPokerDrawFixture("poker_draw_resolve");
        vm.expectRevert("SingleDraw: invalid draw proof");
        pokerEngine.submitDrawProof(
            1,
            player1.addr,
            bytes32(uint256(player0Draw.newCommitment) + 1),
            player0Draw.newEncryptionKeyCommitment,
            player0Draw.newCiphertextRef,
            player0Draw.proof
        );

        PokerDrawFixture memory player1Draw = _loadPokerDrawFixture("poker_draw_resolve_player1");
        pokerEngine.submitDrawProof(
            1,
            player1.addr,
            player0Draw.newCommitment,
            player0Draw.newEncryptionKeyCommitment,
            player0Draw.newCiphertextRef,
            player0Draw.proof
        );
        pokerEngine.submitDrawProof(
            1,
            player2.addr,
            player1Draw.newCommitment,
            player1Draw.newEncryptionKeyCommitment,
            player1Draw.newCiphertextRef,
            player1Draw.proof
        );

        vm.prank(player2.addr);
        pokerEngine.bet(1, 0);
        vm.prank(player1.addr);
        pokerEngine.bet(1, 0);

        PokerShowdownFixture memory showdown = _loadPokerShowdownFixture("poker_showdown");
        vm.expectRevert("SingleDraw: invalid showdown");
        pokerEngine.submitShowdownProof(1, player2.addr, showdown.isTie, showdown.proof);
    }

    function test_PokerTimeoutClaimsTheCurrentHand() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        pokerEngine.initializeGame(1, players, stacks, 0, 20 ether, _defaultPokerConfig(address(this)));
        _submitPokerInitialDealProof(1);
        vm.expectRevert("SingleDraw: active");
        pokerEngine.claimTimeout(1);

        vm.warp(block.timestamp + 61);
        pokerEngine.claimTimeout(1);
        assertFalse(pokerEngine.isGameOver(1));
    }

    function test_PokerFoldEndsTheCurrentHand() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        pokerEngine.initializeGame(1, players, stacks, 0, 20 ether, _defaultPokerConfig(address(this)));
        _submitPokerInitialDealProof(1);
        vm.prank(player1.addr);
        pokerEngine.fold(1);
        assertFalse(pokerEngine.isGameOver(1));
    }

    function test_PokerTieProofAdvancesToNextHand() public {
        address[] memory players = new address[](2);
        players[0] = player1.addr;
        players[1] = player2.addr;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 1_000;
        stacks[1] = 1_000;

        pokerEngine.initializeGame(1, players, stacks, 0, 20 ether, _defaultPokerConfig(address(this)));
        _advanceToShowdown(1);
        _submitPokerTieShowdown(1);
        assertFalse(pokerEngine.isGameOver(1));
        assertEq(pokerEngine.getHandState(1).handNumber, 2);
    }

    function test_RegistryAndSettlementRejectUnauthorizedCallers() public {
        vm.prank(outsider.addr);
        vm.expectRevert();
        registry.registerEngine(
            outsider.addr,
            GameEngineRegistry.EngineMetadata({
                engineType: keccak256("fake"),
                creator: outsider.addr,
                verifier: address(0),
                configHash: bytes32(0),
                creatorRateBps: 100,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        vm.prank(outsider.addr);
        vm.expectRevert();
        registry.setEngineActive(address(numberPickerEngine), false);

        vm.prank(outsider.addr);
        vm.expectRevert();
        settlement.setControllerAuthorization(outsider.addr, true);

        vm.prank(outsider.addr);
        vm.expectRevert();
        settlement.burnPlayerWager(player1.addr, 1 ether);

        vm.prank(outsider.addr);
        vm.expectRevert();
        settlement.mintPlayerReward(player1.addr, 1 ether);

        vm.prank(outsider.addr);
        vm.expectRevert();
        settlement.accrueCreatorForEngine(address(numberPickerEngine), 1 ether);
    }
}
