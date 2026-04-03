// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { DeveloperExpressionRegistry } from "../../src/DeveloperExpressionRegistry.sol";
import { DeveloperRewards } from "../../src/DeveloperRewards.sol";
import { GameCatalog } from "../../src/GameCatalog.sol";
import { GameDeploymentFactory } from "../../src/GameDeploymentFactory.sol";
import { ProtocolSettlement } from "../../src/ProtocolSettlement.sol";
import { ScuroGovernor } from "../../src/ScuroGovernor.sol";
import { ScuroStakingToken } from "../../src/ScuroStakingToken.sol";
import { ScuroToken } from "../../src/ScuroToken.sol";
import { BlackjackController } from "../../src/controllers/BlackjackController.sol";
import { NumberPickerAdapter } from "../../src/controllers/NumberPickerAdapter.sol";
import { PvPController } from "../../src/controllers/PvPController.sol";
import { SlotMachineController } from "../../src/controllers/SlotMachineController.sol";
import { TournamentController } from "../../src/controllers/TournamentController.sol";
import { NumberPickerEngine } from "../../src/engines/NumberPickerEngine.sol";
import { BlackjackEngine } from "../../src/engines/BlackjackEngine.sol";
import { SingleDraw2To7Engine } from "../../src/engines/SingleDraw2To7Engine.sol";
import { SlotMachineEngine } from "../../src/engines/SlotMachineEngine.sol";
import { BlackjackModuleDeployer } from "../../src/factory/BlackjackModuleDeployer.sol";
import { CheminDeFerModuleDeployer } from "../../src/factory/CheminDeFerModuleDeployer.sol";
import { PokerModuleDeployer } from "../../src/factory/PokerModuleDeployer.sol";
import { SoloModuleDeployer } from "../../src/factory/SoloModuleDeployer.sol";
import { VRFCoordinatorMock } from "../../src/mocks/VRFCoordinatorMock.sol";
import { ManualVRFCoordinatorMock } from "./helpers/ManualVRFCoordinatorMock.sol";
import { NumberPickerAdapterHarness } from "./helpers/NumberPickerAdapterHarness.sol";
import { SlotMachineControllerHarness } from "../helpers/SlotMachineControllerHarness.sol";
import { SlotMachinePresetFactory } from "../helpers/SlotMachinePresetFactory.sol";
import { ZkFixtureLoader } from "../helpers/ZkFixtureLoader.sol";

abstract contract BaseE2ETest is ZkFixtureLoader {
    struct Actor {
        address addr;
        uint256 key;
    }

    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant STAKE_AMOUNT = 100 ether;
    uint16 internal constant SOLO_DEVELOPER_BPS = 500;
    uint16 internal constant POKER_DEVELOPER_BPS = 1_000;

    Actor internal player1;
    Actor internal player2;
    Actor internal soloDeveloper;
    Actor internal pokerDeveloper;
    Actor internal outsider;

    ScuroToken internal token;
    ScuroStakingToken internal stakingToken;
    TimelockController internal timelock;
    ScuroGovernor internal governor;
    GameCatalog internal catalog;
    GameDeploymentFactory internal factory;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    TournamentController internal tournamentController;
    PvPController internal pvpController;
    VRFCoordinatorMock internal autoVrfCoordinator;
    ManualVRFCoordinatorMock internal manualVrfCoordinator;
    NumberPickerEngine internal numberPickerEngine;
    NumberPickerEngine internal delayedNumberPickerEngine;
    NumberPickerAdapter internal numberPickerAdapter;
    NumberPickerAdapterHarness internal delayedNumberPickerAdapter;
    SlotMachineEngine internal slotMachineEngine;
    SlotMachineEngine internal delayedSlotMachineEngine;
    SlotMachineController internal slotMachineController;
    SlotMachineControllerHarness internal delayedSlotMachineController;
    SingleDraw2To7Engine internal tournamentPokerEngine;
    SingleDraw2To7Engine internal pvpPokerEngine;
    BlackjackEngine internal blackjackEngine;
    BlackjackController internal blackjackController;

    uint256 internal numberPickerModuleId;
    uint256 internal delayedNumberPickerModuleId;
    uint256 internal slotMachineModuleId;
    uint256 internal delayedSlotMachineModuleId;
    uint256 internal tournamentPokerModuleId;
    uint256 internal pvpPokerModuleId;
    uint256 internal blackjackModuleId;

    uint256 internal numberPickerExpressionTokenId;
    uint256 internal delayedNumberPickerExpressionTokenId;
    uint256 internal slotMachineExpressionTokenId;
    uint256 internal delayedSlotMachineExpressionTokenId;
    uint256 internal pokerExpressionTokenId;
    uint256 internal blackjackExpressionTokenId;

    function setUp() public virtual {
        player1 = _makeActor("player-1");
        player2 = _makeActor("player-2");
        soloDeveloper = _makeActor("solo-developer");
        pokerDeveloper = _makeActor("poker-developer");
        outsider = _makeActor("outsider");

        _deployCore();
        _wireRoles();
        _deployModules();
        _mintExpressions();
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

        catalog = new GameCatalog(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(
            address(token), address(catalog), address(expressionRegistry), address(developerRewards)
        );
        factory = new GameDeploymentFactory(
            address(this),
            address(catalog),
            address(settlement),
            address(new SoloModuleDeployer()),
            address(new BlackjackModuleDeployer()),
            address(new PokerModuleDeployer()),
            address(new CheminDeFerModuleDeployer())
        );

        autoVrfCoordinator = new VRFCoordinatorMock();
        manualVrfCoordinator = new ManualVRFCoordinatorMock();
    }

    function _wireRoles() internal {
        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));

        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));
        developerRewards.grantRole(developerRewards.EPOCH_MANAGER_ROLE(), address(timelock));

        catalog.grantRole(catalog.DEFAULT_ADMIN_ROLE(), address(timelock));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(timelock));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), address(timelock));
        factory.grantRole(factory.DEPLOYER_ROLE(), address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
    }

    function _deployModules() internal {
        GameDeploymentFactory.NumberPickerDeployment memory numberPickerParams =
            GameDeploymentFactory.NumberPickerDeployment({
                vrfCoordinator: address(autoVrfCoordinator),
                configHash: keccak256("number-picker-auto"),
                developerRewardBps: SOLO_DEVELOPER_BPS
            });
        address numberPickerControllerAddress;
        address numberPickerEngineAddress;
        (numberPickerModuleId, numberPickerControllerAddress, numberPickerEngineAddress,) = factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.NumberPicker), abi.encode(numberPickerParams)
        );
        numberPickerAdapter = NumberPickerAdapter(numberPickerControllerAddress);
        numberPickerEngine = NumberPickerEngine(numberPickerEngineAddress);

        delayedNumberPickerEngine = new NumberPickerEngine(address(catalog), address(manualVrfCoordinator));
        delayedNumberPickerAdapter =
            new NumberPickerAdapterHarness(address(settlement), address(catalog), address(delayedNumberPickerEngine));
        delayedNumberPickerModuleId = catalog.registerModule(
            GameCatalog.Module({
                mode: GameCatalog.GameMode.Solo,
                controller: address(delayedNumberPickerAdapter),
                engine: address(delayedNumberPickerEngine),
                engineType: delayedNumberPickerEngine.engineType(),
                verifier: address(0),
                configHash: keccak256("number-picker-manual"),
                developerRewardBps: SOLO_DEVELOPER_BPS,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        GameDeploymentFactory.SlotDeployment memory slotParams = GameDeploymentFactory.SlotDeployment({
            vrfCoordinator: address(autoVrfCoordinator),
            configHash: keccak256("slot-machine-auto"),
            developerRewardBps: SOLO_DEVELOPER_BPS
        });
        address slotControllerAddress;
        address slotEngineAddress;
        (slotMachineModuleId, slotControllerAddress, slotEngineAddress,) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.SlotMachine), abi.encode(slotParams));
        slotMachineController = SlotMachineController(slotControllerAddress);
        slotMachineEngine = SlotMachineEngine(slotEngineAddress);
        _registerSlotPresets(slotMachineEngine);

        delayedSlotMachineEngine = new SlotMachineEngine(address(this), address(catalog), address(manualVrfCoordinator));
        delayedSlotMachineController = new SlotMachineControllerHarness(
            address(settlement), address(catalog), address(delayedSlotMachineEngine)
        );
        delayedSlotMachineModuleId = catalog.registerModule(
            GameCatalog.Module({
                mode: GameCatalog.GameMode.Solo,
                controller: address(delayedSlotMachineController),
                engine: address(delayedSlotMachineEngine),
                engineType: delayedSlotMachineEngine.engineType(),
                verifier: address(0),
                configHash: keccak256("slot-machine-manual"),
                developerRewardBps: SOLO_DEVELOPER_BPS,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );
        _registerSlotPresets(delayedSlotMachineEngine);

        GameDeploymentFactory.PokerDeployment memory tournamentPokerParams = GameDeploymentFactory.PokerDeployment({
            coordinator: address(this),
            smallBlind: 10,
            bigBlind: 20,
            blindEscalationInterval: 180,
            actionWindow: 60,
            configHash: keccak256("single-draw-2-7-tournament"),
            developerRewardBps: POKER_DEVELOPER_BPS
        });
        address tournamentControllerAddress;
        address tournamentPokerEngineAddress;
        (tournamentPokerModuleId, tournamentControllerAddress, tournamentPokerEngineAddress,) =
            factory.deployTournamentModule(
                uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7), abi.encode(tournamentPokerParams)
            );
        tournamentController = TournamentController(tournamentControllerAddress);
        tournamentPokerEngine = SingleDraw2To7Engine(tournamentPokerEngineAddress);

        GameDeploymentFactory.PokerDeployment memory pvpPokerParams = GameDeploymentFactory.PokerDeployment({
            coordinator: address(this),
            smallBlind: 10,
            bigBlind: 20,
            blindEscalationInterval: 180,
            actionWindow: 60,
            configHash: keccak256("single-draw-2-7-pvp"),
            developerRewardBps: POKER_DEVELOPER_BPS
        });
        address pvpControllerAddress;
        address pvpPokerEngineAddress;
        (pvpPokerModuleId, pvpControllerAddress, pvpPokerEngineAddress,) = factory.deployPvPModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7), abi.encode(pvpPokerParams)
        );
        pvpController = PvPController(pvpControllerAddress);
        pvpPokerEngine = SingleDraw2To7Engine(pvpPokerEngineAddress);

        GameDeploymentFactory.BlackjackDeployment memory blackjackParams = GameDeploymentFactory.BlackjackDeployment({
            coordinator: address(this),
            defaultActionWindow: 60,
            configHash: keccak256("double-deck-blackjack-zk-v1"),
            developerRewardBps: SOLO_DEVELOPER_BPS
        });
        address blackjackControllerAddress;
        address blackjackEngineAddress;
        (blackjackModuleId, blackjackControllerAddress, blackjackEngineAddress,) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.Blackjack), abi.encode(blackjackParams));
        blackjackController = BlackjackController(blackjackControllerAddress);
        blackjackEngine = BlackjackEngine(blackjackEngineAddress);
    }

    function _mintExpressions() internal {
        bytes32 numberPickerEngineType = numberPickerEngine.engineType();
        bytes32 delayedNumberPickerEngineType = delayedNumberPickerEngine.engineType();
        bytes32 slotMachineEngineType = slotMachineEngine.engineType();
        bytes32 delayedSlotMachineEngineType = delayedSlotMachineEngine.engineType();
        bytes32 tournamentPokerEngineType = tournamentPokerEngine.engineType();
        bytes32 blackjackEngineType = blackjackEngine.engineType();

        vm.prank(soloDeveloper.addr);
        numberPickerExpressionTokenId = expressionRegistry.mintExpression(
            numberPickerEngineType, keccak256("number-picker-auto"), "ipfs://scuro/number-picker-auto"
        );

        vm.prank(soloDeveloper.addr);
        delayedNumberPickerExpressionTokenId = expressionRegistry.mintExpression(
            delayedNumberPickerEngineType, keccak256("number-picker-manual"), "ipfs://scuro/number-picker-manual"
        );

        vm.prank(soloDeveloper.addr);
        slotMachineExpressionTokenId = expressionRegistry.mintExpression(
            slotMachineEngineType, keccak256("slot-machine"), "ipfs://scuro/slot-machine"
        );

        vm.prank(soloDeveloper.addr);
        delayedSlotMachineExpressionTokenId = expressionRegistry.mintExpression(
            delayedSlotMachineEngineType, keccak256("slot-machine-manual"), "ipfs://scuro/slot-machine-manual"
        );

        vm.prank(pokerDeveloper.addr);
        pokerExpressionTokenId = expressionRegistry.mintExpression(
            tournamentPokerEngineType, keccak256("single-draw-2-7"), "ipfs://scuro/single-draw-2-7"
        );

        vm.prank(soloDeveloper.addr);
        blackjackExpressionTokenId = expressionRegistry.mintExpression(
            blackjackEngineType,
            keccak256("double-deck-blackjack-zk-v1"),
            "ipfs://scuro/double-deck-blackjack-zk-v1"
        );
    }

    function _seedActors() internal {
        token.mint(player1.addr, PLAYER_FUNDS);
        token.mint(player2.addr, PLAYER_FUNDS);
        token.mint(soloDeveloper.addr, PLAYER_FUNDS / 10);
        token.mint(pokerDeveloper.addr, PLAYER_FUNDS / 10);
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

    function _registerSlotPresets(SlotMachineEngine engine) internal {
        engine.registerPreset(SlotMachinePresetFactory.basePreset(1));
        engine.registerPreset(SlotMachinePresetFactory.freeSpinPreset(2));
        engine.registerPreset(SlotMachinePresetFactory.pickPreset(3));
        engine.registerPreset(SlotMachinePresetFactory.holdPreset(4));
    }

    function _createTournament(uint256 entryFee, uint256 rewardPool, uint256 startingStack)
        internal
        returns (uint256 tournamentId, uint256 gameId)
    {
        tournamentId =
            tournamentController.createTournament(entryFee, rewardPool, startingStack, pokerExpressionTokenId);
        gameId = tournamentController.startGameForPlayers(tournamentId, player1.addr, player2.addr);
    }

    function _createPvPSession(uint256 stake, uint256 rewardPool, uint256 startingStack)
        internal
        returns (uint256 sessionId)
    {
        sessionId = pvpController.createSession(
            player1.addr, player2.addr, stake, rewardPool, startingStack, pokerExpressionTokenId
        );
    }

    function _playTournamentAllInSingleDraw(uint256 gameId, address winner) internal {
        _playAllInSingleDraw(tournamentPokerEngine, gameId, winner);
    }

    function _playPvPAllInSingleDraw(uint256 sessionId, address winner) internal {
        _playAllInSingleDraw(pvpPokerEngine, sessionId, winner);
    }

    function _playAllInSingleDraw(SingleDraw2To7Engine engine, uint256 gameId, address winner) internal {
        _submitPokerInitialDealProof(engine, gameId);

        vm.prank(player1.addr);
        engine.bet(gameId, 990);
        vm.prank(player2.addr);
        engine.bet(gameId, 980);

        _resolvePokerDrawPhase(engine, gameId);

        vm.prank(player2.addr);
        engine.bet(gameId, 0);
        vm.prank(player1.addr);
        engine.bet(gameId, 0);

        _submitPokerWinnerShowdown(engine, gameId, winner);
    }

    function _advanceToShowdown(SingleDraw2To7Engine engine, uint256 gameId) internal {
        _submitPokerInitialDealProof(engine, gameId);

        vm.prank(player1.addr);
        engine.bet(gameId, 10);
        vm.prank(player2.addr);
        engine.bet(gameId, 0);

        _resolvePokerDrawPhase(engine, gameId);

        vm.prank(player2.addr);
        engine.bet(gameId, 0);
        vm.prank(player1.addr);
        engine.bet(gameId, 0);
    }

    function _submitPokerInitialDealProof(SingleDraw2To7Engine engine, uint256 gameId) internal {
        PokerInitialDealFixture memory fixture = _loadPokerInitialDealFixture();
        engine.submitInitialDealProof(
            gameId,
            fixture.deckCommitment,
            fixture.handNonce,
            fixture.handCommitments,
            fixture.encryptionKeyCommitments,
            fixture.ciphertextRefs,
            fixture.proof
        );
    }

    function _resolvePokerDrawPhase(SingleDraw2To7Engine engine, uint256 gameId) internal {
        uint8[] memory empty = new uint8[](0);
        vm.prank(player2.addr);
        engine.declareDraw(gameId, empty);
        vm.prank(player1.addr);
        engine.declareDraw(gameId, empty);

        PokerDrawFixture memory player1Draw = _loadPokerDrawFixture("poker_draw_resolve");
        PokerDrawFixture memory player2Draw = _loadPokerDrawFixture("poker_draw_resolve_player1");
        engine.submitDrawProof(
            gameId,
            player1.addr,
            player1Draw.newCommitment,
            player1Draw.newEncryptionKeyCommitment,
            player1Draw.newCiphertextRef,
            player1Draw.proof
        );
        engine.submitDrawProof(
            gameId,
            player2.addr,
            player2Draw.newCommitment,
            player2Draw.newEncryptionKeyCommitment,
            player2Draw.newCiphertextRef,
            player2Draw.proof
        );
    }

    function _submitPokerWinnerShowdown(SingleDraw2To7Engine engine, uint256 gameId, address winner) internal {
        PokerShowdownFixture memory fixture = _loadPokerShowdownFixture("poker_showdown");
        engine.submitShowdownProof(gameId, winner, fixture.isTie, fixture.proof);
    }

    function _submitPokerTieShowdown(SingleDraw2To7Engine engine, uint256 gameId) internal {
        PokerShowdownFixture memory fixture = _loadPokerShowdownFixture("poker_showdown_tie");
        engine.submitShowdownProof(gameId, address(0), fixture.isTie, fixture.proof);
    }

    function _closeEpoch() internal returns (uint256 closedEpoch) {
        vm.warp(block.timestamp + developerRewards.epochDuration() + 1);
        closedEpoch = developerRewards.closeCurrentEpoch();
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

    function _assertDeveloperAccrual(address developer, uint256 epoch, uint256 amount) internal view {
        assertEq(developerRewards.epochAccrual(epoch, developer), amount, "developer accrual");
    }
}
