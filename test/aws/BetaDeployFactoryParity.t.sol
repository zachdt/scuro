// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {DeveloperExpressionRegistry} from "../../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../../src/DeveloperRewards.sol";
import {GameCatalog} from "../../src/GameCatalog.sol";
import {GameDeploymentFactory} from "../../src/GameDeploymentFactory.sol";
import {ProtocolSettlement} from "../../src/ProtocolSettlement.sol";
import {ScuroGovernor} from "../../src/ScuroGovernor.sol";
import {ScuroStakingToken} from "../../src/ScuroStakingToken.sol";
import {ScuroToken} from "../../src/ScuroToken.sol";
import {BlackjackController} from "../../src/controllers/BlackjackController.sol";
import {NumberPickerAdapter} from "../../src/controllers/NumberPickerAdapter.sol";
import {PvPController} from "../../src/controllers/PvPController.sol";
import {TournamentController} from "../../src/controllers/TournamentController.sol";
import {NumberPickerEngine} from "../../src/engines/NumberPickerEngine.sol";
import {BlackjackEngine} from "../../src/engines/BlackjackEngine.sol";
import {SingleDraw2To7Engine} from "../../src/engines/SingleDraw2To7Engine.sol";
import {BlackjackModuleDeployer} from "../../src/factory/BlackjackModuleDeployer.sol";
import {CheminDeFerModuleDeployer} from "../../src/factory/CheminDeFerModuleDeployer.sol";
import {PokerModuleDeployer} from "../../src/factory/PokerModuleDeployer.sol";
import {SoloModuleDeployer} from "../../src/factory/SoloModuleDeployer.sol";
import {VRFCoordinatorMock} from "../../src/mocks/VRFCoordinatorMock.sol";

contract BetaDeployFactoryParityTest is Test {
    using stdJson for string;

    string internal constant GAS_THRESHOLDS_PATH = "script/aws/deploy-gas-thresholds.json";

    address internal constant PLAYER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant PLAYER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant SOLO_DEVELOPER = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address internal constant POKER_DEVELOPER = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    address internal constant EXPRESSION_ADMIN = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant DEVELOPER_FUNDS = 1_000 ether;

    ScuroToken internal token;
    ScuroStakingToken internal stakingToken;
    TimelockController internal timelock;
    ScuroGovernor internal governor;
    GameCatalog internal catalog;
    GameDeploymentFactory internal factory;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    VRFCoordinatorMock internal vrfCoordinator;

    function setUp() public {
        _deployCore();
    }

    function test_CanonicalBetaDeployUsesFactoryAndTransfersFactoryRoles() public {
        (
            uint256 numberPickerModuleId,
            NumberPickerAdapter numberPickerAdapter,
            NumberPickerEngine numberPickerEngine,
            uint256 tournamentPokerModuleId,
            TournamentController tournamentController,
            SingleDraw2To7Engine tournamentPokerEngine,
            uint256 pvpPokerModuleId,
            PvPController pvpController,
            SingleDraw2To7Engine _pvpPokerEngine,
            uint256 blackjackModuleId,
            BlackjackController blackjackController,
            BlackjackEngine blackjackEngine
        ) = _deployModules();

        assertTrue(address(factory) != address(0));
        assertEq(numberPickerModuleId, 1);
        assertEq(tournamentPokerModuleId, 2);
        assertEq(pvpPokerModuleId, 3);
        assertEq(blackjackModuleId, 4);
        assertEq(catalog.controllerModuleIds(address(numberPickerAdapter)), numberPickerModuleId);
        assertEq(catalog.controllerModuleIds(address(tournamentController)), tournamentPokerModuleId);
        assertEq(catalog.controllerModuleIds(address(pvpController)), pvpPokerModuleId);
        assertEq(catalog.controllerModuleIds(address(blackjackController)), blackjackModuleId);
        assertTrue(address(_pvpPokerEngine) != address(0));

        _finalize(numberPickerEngine, tournamentPokerEngine, blackjackEngine);

        assertTrue(catalog.hasRole(catalog.REGISTRAR_ROLE(), address(factory)));
        assertTrue(catalog.hasRole(catalog.REGISTRAR_ROLE(), address(timelock)));
        assertTrue(catalog.hasRole(catalog.DEFAULT_ADMIN_ROLE(), address(timelock)));
        assertFalse(catalog.hasRole(catalog.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(catalog.hasRole(catalog.REGISTRAR_ROLE(), address(this)));

        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), address(timelock)));
        assertTrue(factory.hasRole(factory.DEPLOYER_ROLE(), address(timelock)));
        assertFalse(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(factory.hasRole(factory.DEPLOYER_ROLE(), address(this)));
    }

    function test_Gas_FactoryDeploysNumberPickerWithinBudget() public {
        uint256 gasBefore = gasleft();
        factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.NumberPicker),
            abi.encode(
                GameDeploymentFactory.NumberPickerDeployment({
                    vrfCoordinator: address(vrfCoordinator),
                    configHash: keccak256("number-picker-auto"),
                    developerRewardBps: 500
                })
            )
        );
        uint256 gasUsed = gasBefore - gasleft();

        assertLe(gasUsed, _gasBudget(".factory_entrypoints.number_picker"));
    }

    function test_Gas_FactoryDeploysTournamentPokerWithinBudget() public {
        uint256 gasBefore = gasleft();
        factory.deployTournamentModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7),
            abi.encode(_pokerDeployment(keccak256("single-draw-2-7-tournament")))
        );
        uint256 gasUsed = gasBefore - gasleft();

        assertLe(gasUsed, _gasBudget(".factory_entrypoints.poker_tournament"));
    }

    function test_Gas_FactoryDeploysPvPPokerWithinBudget() public {
        uint256 gasBefore = gasleft();
        factory.deployPvPModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7),
            abi.encode(_pokerDeployment(keccak256("single-draw-2-7-pvp")))
        );
        uint256 gasUsed = gasBefore - gasleft();

        assertLe(gasUsed, _gasBudget(".factory_entrypoints.poker_pvp"));
    }

    function test_Gas_FactoryDeploysBlackjackWithinBudget() public {
        uint256 gasBefore = gasleft();
        factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.Blackjack),
            abi.encode(
                GameDeploymentFactory.BlackjackDeployment({
                    coordinator: address(this),
                    defaultActionWindow: 60,
                    configHash: keccak256("double-deck-blackjack-zk-v1"),
                    developerRewardBps: 500
                })
            )
        );
        uint256 gasUsed = gasBefore - gasleft();

        assertLe(gasUsed, _gasBudget(".factory_entrypoints.blackjack"));
    }

    function _deployCore() internal {
        token = new ScuroToken(address(this));
        stakingToken = new ScuroStakingToken(address(token));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(1, proposers, executors, address(this));
        governor = new ScuroGovernor(stakingToken, timelock, 1, 45818, 1 ether);
        catalog = new GameCatalog(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(address(token), address(catalog), address(expressionRegistry), address(developerRewards));

        factory = new GameDeploymentFactory(
            address(this),
            address(catalog),
            address(settlement),
            address(new SoloModuleDeployer()),
            address(new BlackjackModuleDeployer()),
            address(new PokerModuleDeployer()),
            address(new CheminDeFerModuleDeployer())
        );
        vrfCoordinator = new VRFCoordinatorMock();

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));
        developerRewards.grantRole(developerRewards.EPOCH_MANAGER_ROLE(), address(timelock));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));
    }

    function _deployModules()
        internal
        returns (
            uint256 numberPickerModuleId,
            NumberPickerAdapter numberPickerAdapter,
            NumberPickerEngine numberPickerEngine,
            uint256 tournamentPokerModuleId,
            TournamentController tournamentController,
            SingleDraw2To7Engine tournamentPokerEngine,
            uint256 pvpPokerModuleId,
            PvPController pvpController,
            SingleDraw2To7Engine pvpPokerEngine,
            uint256 blackjackModuleId,
            BlackjackController blackjackController,
            BlackjackEngine blackjackEngine
        )
    {
        address controllerAddress;
        address engineAddress;
        (numberPickerModuleId, controllerAddress, engineAddress,) = factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.NumberPicker),
            abi.encode(
                GameDeploymentFactory.NumberPickerDeployment({
                    vrfCoordinator: address(vrfCoordinator),
                    configHash: keccak256("number-picker-auto"),
                    developerRewardBps: 500
                })
            )
        );
        numberPickerAdapter = NumberPickerAdapter(controllerAddress);
        numberPickerEngine = NumberPickerEngine(engineAddress);

        (tournamentPokerModuleId, controllerAddress, engineAddress,) = factory.deployTournamentModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7),
            abi.encode(_pokerDeployment(keccak256("single-draw-2-7-tournament")))
        );
        tournamentController = TournamentController(controllerAddress);
        tournamentPokerEngine = SingleDraw2To7Engine(engineAddress);

        (pvpPokerModuleId, controllerAddress, engineAddress,) = factory.deployPvPModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7),
            abi.encode(_pokerDeployment(keccak256("single-draw-2-7-pvp")))
        );
        pvpController = PvPController(controllerAddress);
        pvpPokerEngine = SingleDraw2To7Engine(engineAddress);

        (blackjackModuleId, controllerAddress, engineAddress,) = factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.Blackjack),
            abi.encode(
                GameDeploymentFactory.BlackjackDeployment({
                    coordinator: address(this),
                    defaultActionWindow: 60,
                    configHash: keccak256("double-deck-blackjack-zk-v1"),
                    developerRewardBps: 500
                })
            )
        );
        blackjackController = BlackjackController(controllerAddress);
        blackjackEngine = BlackjackEngine(engineAddress);
    }

    function _finalize(
        NumberPickerEngine numberPickerEngine,
        SingleDraw2To7Engine tournamentPokerEngine,
        BlackjackEngine blackjackEngine
    ) internal {
        vm.startPrank(EXPRESSION_ADMIN);
        uint256 numberPickerExpressionTokenId = expressionRegistry.mintExpression(
            numberPickerEngine.engineType(), keccak256("number-picker-auto"), "ipfs://scuro/number-picker-auto"
        );
        uint256 blackjackExpressionTokenId = expressionRegistry.mintExpression(
            blackjackEngine.engineType(),
            keccak256("double-deck-blackjack-zk-v1"),
            "ipfs://scuro/double-deck-blackjack-zk-v1"
        );
        uint256 pokerExpressionTokenId = expressionRegistry.mintExpression(
            tournamentPokerEngine.engineType(), keccak256("single-draw-2-7"), "ipfs://scuro/single-draw-2-7"
        );

        expressionRegistry.transferFrom(EXPRESSION_ADMIN, SOLO_DEVELOPER, numberPickerExpressionTokenId);
        expressionRegistry.transferFrom(EXPRESSION_ADMIN, SOLO_DEVELOPER, blackjackExpressionTokenId);
        expressionRegistry.transferFrom(EXPRESSION_ADMIN, POKER_DEVELOPER, pokerExpressionTokenId);
        vm.stopPrank();

        token.mint(PLAYER1, PLAYER_FUNDS);
        token.mint(PLAYER2, PLAYER_FUNDS);
        token.mint(address(this), PLAYER_FUNDS);
        token.mint(SOLO_DEVELOPER, DEVELOPER_FUNDS);
        token.mint(POKER_DEVELOPER, DEVELOPER_FUNDS);

        catalog.grantRole(catalog.DEFAULT_ADMIN_ROLE(), address(timelock));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(timelock));
        catalog.renounceRole(catalog.DEFAULT_ADMIN_ROLE(), address(this));
        catalog.renounceRole(catalog.REGISTRAR_ROLE(), address(this));
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), address(timelock));
        factory.grantRole(factory.DEPLOYER_ROLE(), address(timelock));
        factory.renounceRole(factory.DEFAULT_ADMIN_ROLE(), address(this));
        factory.renounceRole(factory.DEPLOYER_ROLE(), address(this));
    }

    function _pokerDeployment(bytes32 configHash)
        internal
        view
        returns (GameDeploymentFactory.PokerDeployment memory)
    {
        return GameDeploymentFactory.PokerDeployment({
            coordinator: address(this),
            smallBlind: 10,
            bigBlind: 20,
            blindEscalationInterval: 180,
            actionWindow: 60,
            configHash: configHash,
            developerRewardBps: 1_000
        });
    }

    function _gasBudget(string memory path) internal view returns (uint256) {
        string memory json = vm.readFile(GAS_THRESHOLDS_PATH);
        return json.readUint(path);
    }
}
