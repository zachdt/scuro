// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { CreatorRewards } from "../../src/CreatorRewards.sol";
import { GameEngineRegistry } from "../../src/GameEngineRegistry.sol";
import { ProtocolSettlement } from "../../src/ProtocolSettlement.sol";
import { ScuroGovernor } from "../../src/ScuroGovernor.sol";
import { ScuroStakingToken } from "../../src/ScuroStakingToken.sol";
import { ScuroToken } from "../../src/ScuroToken.sol";
import { BlackjackController } from "../../src/controllers/BlackjackController.sol";
import { NumberPickerAdapter } from "../../src/controllers/NumberPickerAdapter.sol";
import { PvPController } from "../../src/controllers/PvPController.sol";
import { TournamentController } from "../../src/controllers/TournamentController.sol";
import { NumberPickerEngine } from "../../src/engines/NumberPickerEngine.sol";
import { SingleDeckBlackjackEngine } from "../../src/engines/SingleDeckBlackjackEngine.sol";
import { SingleDraw2To7Engine } from "../../src/engines/SingleDraw2To7Engine.sol";
import { VRFCoordinatorMock } from "../../src/mocks/VRFCoordinatorMock.sol";
import { BlackjackVerifierBundle } from "../../src/verifiers/BlackjackVerifierBundle.sol";
import { PokerVerifierBundle } from "../../src/verifiers/PokerVerifierBundle.sol";
import { BlackjackActionResolveVerifier } from "../../src/verifiers/generated/BlackjackActionResolveVerifier.sol";
import { BlackjackInitialDealVerifier } from "../../src/verifiers/generated/BlackjackInitialDealVerifier.sol";
import { BlackjackShowdownVerifier } from "../../src/verifiers/generated/BlackjackShowdownVerifier.sol";
import { PokerDrawResolveVerifier } from "../../src/verifiers/generated/PokerDrawResolveVerifier.sol";
import { PokerInitialDealVerifier } from "../../src/verifiers/generated/PokerInitialDealVerifier.sol";
import { PokerShowdownVerifier } from "../../src/verifiers/generated/PokerShowdownVerifier.sol";
import { ManualVRFCoordinatorMock } from "./helpers/ManualVRFCoordinatorMock.sol";
import { NumberPickerAdapterHarness } from "./helpers/NumberPickerAdapterHarness.sol";
import { ZkFixtureLoader } from "../helpers/ZkFixtureLoader.sol";

abstract contract BaseE2ETest is ZkFixtureLoader {
    struct Actor {
        address addr;
        uint256 key;
    }

    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant STAKE_AMOUNT = 100 ether;
    uint16 internal constant SOLO_CREATOR_BPS = 500;
    uint16 internal constant POKER_CREATOR_BPS = 1_000;

    Actor internal player1;
    Actor internal player2;
    Actor internal soloCreator;
    Actor internal pokerCreator;
    Actor internal outsider;

    ScuroToken internal token;
    ScuroStakingToken internal stakingToken;
    TimelockController internal timelock;
    ScuroGovernor internal governor;
    GameEngineRegistry internal registry;
    CreatorRewards internal creatorRewards;
    ProtocolSettlement internal settlement;
    TournamentController internal tournamentController;
    PvPController internal pvpController;
    VRFCoordinatorMock internal autoVrfCoordinator;
    ManualVRFCoordinatorMock internal manualVrfCoordinator;
    NumberPickerEngine internal numberPickerEngine;
    NumberPickerEngine internal delayedNumberPickerEngine;
    NumberPickerAdapter internal numberPickerAdapter;
    NumberPickerAdapterHarness internal delayedNumberPickerAdapter;
    SingleDraw2To7Engine internal pokerEngine;
    PokerVerifierBundle internal pokerVerifierBundle;
    SingleDeckBlackjackEngine internal blackjackEngine;
    BlackjackVerifierBundle internal blackjackVerifierBundle;
    BlackjackController internal blackjackController;

    function setUp() public virtual {
        player1 = _makeActor("player-1");
        player2 = _makeActor("player-2");
        soloCreator = _makeActor("solo-creator");
        pokerCreator = _makeActor("poker-creator");
        outsider = _makeActor("outsider");

        _deployCore();
        _wireRoles();
        _registerEngines();
        _seedActors();
    }

    function _makeActor(string memory label) internal returns (Actor memory actor) {
        (actor.addr, actor.key) = makeAddrAndKey(label);
    }

    function _deployCore() internal {
        token = new ScuroToken(address(this));
        stakingToken = new ScuroStakingToken(address(token));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(1, proposers, executors, address(this));
        governor = new ScuroGovernor(stakingToken, timelock, 1, 5, 1 ether);

        registry = new GameEngineRegistry(address(this));
        creatorRewards = new CreatorRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(address(this), address(token), address(registry), address(creatorRewards));

        tournamentController = new TournamentController(address(this), address(settlement), address(registry));
        pvpController = new PvPController(address(this), address(settlement), address(registry));

        autoVrfCoordinator = new VRFCoordinatorMock();
        manualVrfCoordinator = new ManualVRFCoordinatorMock();
        numberPickerEngine = new NumberPickerEngine(address(this), address(autoVrfCoordinator));
        delayedNumberPickerEngine = new NumberPickerEngine(address(this), address(manualVrfCoordinator));
        numberPickerAdapter =
            new NumberPickerAdapter(address(this), address(settlement), address(registry), address(numberPickerEngine));
        delayedNumberPickerAdapter = new NumberPickerAdapterHarness(
            address(this), address(settlement), address(registry), address(delayedNumberPickerEngine)
        );

        PokerInitialDealVerifier pokerInitialDealVerifier = new PokerInitialDealVerifier();
        PokerDrawResolveVerifier pokerDrawResolveVerifier = new PokerDrawResolveVerifier();
        PokerShowdownVerifier pokerShowdownVerifier = new PokerShowdownVerifier();
        pokerVerifierBundle = new PokerVerifierBundle(
            address(this),
            address(pokerInitialDealVerifier),
            address(pokerDrawResolveVerifier),
            address(pokerShowdownVerifier)
        );
        pokerEngine = new SingleDraw2To7Engine();

        BlackjackInitialDealVerifier blackjackInitialDealVerifier = new BlackjackInitialDealVerifier();
        BlackjackActionResolveVerifier blackjackActionResolveVerifier = new BlackjackActionResolveVerifier();
        BlackjackShowdownVerifier blackjackShowdownVerifier = new BlackjackShowdownVerifier();
        blackjackVerifierBundle = new BlackjackVerifierBundle(
            address(this),
            address(blackjackInitialDealVerifier),
            address(blackjackActionResolveVerifier),
            address(blackjackShowdownVerifier)
        );
        blackjackEngine = new SingleDeckBlackjackEngine(address(this), address(blackjackVerifierBundle), 60);
        blackjackController =
            new BlackjackController(address(this), address(settlement), address(registry), address(blackjackEngine));
    }

    function _wireRoles() internal {
        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(creatorRewards));

        creatorRewards.grantRole(creatorRewards.SETTLEMENT_ROLE(), address(settlement));
        creatorRewards.grantRole(creatorRewards.EPOCH_MANAGER_ROLE(), address(timelock));

        settlement.setControllerAuthorization(address(tournamentController), true);
        settlement.setControllerAuthorization(address(pvpController), true);
        settlement.setControllerAuthorization(address(numberPickerAdapter), true);
        settlement.setControllerAuthorization(address(delayedNumberPickerAdapter), true);
        settlement.setControllerAuthorization(address(blackjackController), true);

        numberPickerEngine.grantRole(numberPickerEngine.ADAPTER_ROLE(), address(numberPickerAdapter));
        delayedNumberPickerEngine.grantRole(
            delayedNumberPickerEngine.ADAPTER_ROLE(), address(delayedNumberPickerAdapter)
        );
        blackjackEngine.grantRole(blackjackEngine.CONTROLLER_ROLE(), address(blackjackController));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
    }

    function _registerEngines() internal {
        registry.registerEngine(
            address(numberPickerEngine),
            GameEngineRegistry.EngineMetadata({
                engineType: numberPickerEngine.ENGINE_TYPE(),
                creator: soloCreator.addr,
                verifier: address(0),
                configHash: keccak256("number-picker-auto"),
                creatorRateBps: SOLO_CREATOR_BPS,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        registry.registerEngine(
            address(delayedNumberPickerEngine),
            GameEngineRegistry.EngineMetadata({
                engineType: delayedNumberPickerEngine.ENGINE_TYPE(),
                creator: soloCreator.addr,
                verifier: address(0),
                configHash: keccak256("number-picker-manual"),
                creatorRateBps: SOLO_CREATOR_BPS,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        registry.registerEngine(
            address(pokerEngine),
            GameEngineRegistry.EngineMetadata({
                engineType: pokerEngine.ENGINE_TYPE(),
                creator: pokerCreator.addr,
                verifier: address(pokerVerifierBundle),
                configHash: keccak256("single-draw-2-7"),
                creatorRateBps: POKER_CREATOR_BPS,
                active: true,
                supportsTournament: true,
                supportsPvP: true,
                supportsSolo: false
            })
        );

        registry.registerEngine(
            address(blackjackEngine),
            GameEngineRegistry.EngineMetadata({
                engineType: blackjackEngine.ENGINE_TYPE(),
                creator: soloCreator.addr,
                verifier: address(blackjackVerifierBundle),
                configHash: keccak256("single-deck-blackjack-zk"),
                creatorRateBps: SOLO_CREATOR_BPS,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );
    }

    function _seedActors() internal {
        token.mint(player1.addr, PLAYER_FUNDS);
        token.mint(player2.addr, PLAYER_FUNDS);
        token.mint(soloCreator.addr, PLAYER_FUNDS / 10);
        token.mint(pokerCreator.addr, PLAYER_FUNDS / 10);
    }

    function _approveSettlement(Actor memory actor, uint256 amount) internal {
        vm.prank(actor.addr);
        token.approve(address(settlement), amount);
    }

    function _approveStaking(Actor memory actor, uint256 amount) internal {
        vm.prank(actor.addr);
        token.approve(address(stakingToken), amount);
    }

    function _stakeAndDelegate(Actor memory actor, uint256 amount) internal {
        _approveStaking(actor, amount);
        vm.startPrank(actor.addr);
        stakingToken.stake(amount);
        stakingToken.delegate(actor.addr);
        vm.stopPrank();
    }

    function _defaultPokerConfig(address coordinator) internal view returns (bytes memory) {
        return
            abi.encode(uint256(10), uint256(20), uint256(180), uint256(60), address(pokerVerifierBundle), coordinator);
    }

    function _createTournament(uint256 entryFee, uint256 rewardPool, uint256 startingStack)
        internal
        returns (uint256 tournamentId, uint256 gameId)
    {
        tournamentId = tournamentController.createTournament(
            entryFee, rewardPool, address(pokerEngine), startingStack, _defaultPokerConfig(address(this))
        );
        gameId = tournamentController.startGameForPlayers(tournamentId, player1.addr, player2.addr);
    }

    function _createPvPSession(uint256 stake, uint256 rewardPool, uint256 startingStack)
        internal
        returns (uint256 sessionId)
    {
        sessionId = pvpController.createSession(
            address(pokerEngine),
            player1.addr,
            player2.addr,
            stake,
            rewardPool,
            startingStack,
            _defaultPokerConfig(address(this))
        );
    }

    function _playAllInSingleDraw(uint256 gameId, address winner) internal {
        _submitPokerInitialDealProof(gameId);

        vm.prank(player1.addr);
        pokerEngine.bet(gameId, 990);
        vm.prank(player2.addr);
        pokerEngine.bet(gameId, 980);

        _resolvePokerDrawPhase(gameId);

        vm.prank(player2.addr);
        pokerEngine.bet(gameId, 0);
        vm.prank(player1.addr);
        pokerEngine.bet(gameId, 0);

        _submitPokerWinnerShowdown(gameId, winner);
    }

    function _advanceToShowdown(uint256 gameId) internal {
        _submitPokerInitialDealProof(gameId);

        vm.prank(player1.addr);
        pokerEngine.bet(gameId, 10);
        vm.prank(player2.addr);
        pokerEngine.bet(gameId, 0);

        _resolvePokerDrawPhase(gameId);

        vm.prank(player2.addr);
        pokerEngine.bet(gameId, 0);
        vm.prank(player1.addr);
        pokerEngine.bet(gameId, 0);
    }

    function _submitPokerInitialDealProof(uint256 gameId) internal {
        PokerInitialDealFixture memory fixture = _loadPokerInitialDealFixture();
        pokerEngine.submitInitialDealProof(
            gameId,
            fixture.deckCommitment,
            fixture.handNonce,
            fixture.handCommitments,
            fixture.encryptionKeyCommitments,
            fixture.ciphertextRefs,
            fixture.proof
        );
    }

    function _resolvePokerDrawPhase(uint256 gameId) internal {
        uint8[] memory empty = new uint8[](0);
        vm.prank(player2.addr);
        pokerEngine.declareDraw(gameId, empty);
        vm.prank(player1.addr);
        pokerEngine.declareDraw(gameId, empty);

        PokerDrawFixture memory player1Draw = _loadPokerDrawFixture("poker_draw_resolve");
        PokerDrawFixture memory player2Draw = _loadPokerDrawFixture("poker_draw_resolve_player1");
        pokerEngine.submitDrawProof(
            gameId,
            player1.addr,
            player1Draw.newCommitment,
            player1Draw.newEncryptionKeyCommitment,
            player1Draw.newCiphertextRef,
            player1Draw.proof
        );
        pokerEngine.submitDrawProof(
            gameId,
            player2.addr,
            player2Draw.newCommitment,
            player2Draw.newEncryptionKeyCommitment,
            player2Draw.newCiphertextRef,
            player2Draw.proof
        );
    }

    function _submitPokerWinnerShowdown(uint256 gameId, address winner) internal {
        PokerShowdownFixture memory fixture = _loadPokerShowdownFixture("poker_showdown");
        pokerEngine.submitShowdownProof(gameId, winner, fixture.isTie, fixture.proof);
    }

    function _submitPokerTieShowdown(uint256 gameId) internal {
        PokerShowdownFixture memory fixture = _loadPokerShowdownFixture("poker_showdown_tie");
        pokerEngine.submitShowdownProof(gameId, address(0), fixture.isTie, fixture.proof);
    }

    function _closeEpoch() internal returns (uint256 closedEpoch) {
        vm.warp(block.timestamp + creatorRewards.epochDuration() + 1);
        closedEpoch = creatorRewards.closeCurrentEpoch();
    }

    function _executeGovernanceProposal(address target, bytes memory data, string memory description) internal {
        _stakeAndDelegate(player1, STAKE_AMOUNT);
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = target;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;

        vm.prank(player1.addr);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(player1.addr);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + 2);
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    function _assertPlayerBalances(uint256 player1Balance, uint256 player2Balance) internal view {
        assertEq(token.balanceOf(player1.addr), player1Balance, "player1 balance");
        assertEq(token.balanceOf(player2.addr), player2Balance, "player2 balance");
    }

    function _assertCreatorAccrual(address creator, uint256 epoch, uint256 amount) internal view {
        assertEq(creatorRewards.epochAccrual(epoch, creator), amount, "creator accrual");
    }
}
