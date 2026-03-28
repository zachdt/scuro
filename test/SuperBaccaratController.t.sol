// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../src/DeveloperRewards.sol";
import {GameCatalog} from "../src/GameCatalog.sol";
import {GameDeploymentFactory} from "../src/GameDeploymentFactory.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroToken} from "../src/ScuroToken.sol";
import {SuperBaccaratController} from "../src/controllers/SuperBaccaratController.sol";
import {SuperBaccaratEngine} from "../src/engines/SuperBaccaratEngine.sol";
import {BlackjackModuleDeployer} from "../src/factory/BlackjackModuleDeployer.sol";
import {CheminDeFerModuleDeployer} from "../src/factory/CheminDeFerModuleDeployer.sol";
import {PokerModuleDeployer} from "../src/factory/PokerModuleDeployer.sol";
import {SoloModuleDeployer} from "../src/factory/SoloModuleDeployer.sol";
import {BaccaratTypes} from "../src/libraries/BaccaratTypes.sol";
import {VRFCoordinatorMock} from "../src/mocks/VRFCoordinatorMock.sol";
import {ManualVRFCoordinatorMock} from "./e2e/helpers/ManualVRFCoordinatorMock.sol";
import {BaccaratRulesHarness} from "./helpers/BaccaratRulesHarness.sol";

contract SuperBaccaratControllerTest is Test {
    ScuroToken internal token;
    GameCatalog internal catalog;
    GameDeploymentFactory internal factory;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    VRFCoordinatorMock internal autoVrfCoordinator;
    ManualVRFCoordinatorMock internal manualVrfCoordinator;
    BaccaratRulesHarness internal rulesHarness;

    SuperBaccaratController internal autoController;
    SuperBaccaratEngine internal autoEngine;
    SuperBaccaratController internal delayedController;
    SuperBaccaratEngine internal delayedEngine;
    uint256 internal delayedModuleId;

    address internal developer = address(0xBEEF);
    address internal player = address(0x111);
    uint256 internal expressionTokenId;

    function setUp() public {
        token = new ScuroToken(address(this));
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
        autoVrfCoordinator = new VRFCoordinatorMock();
        manualVrfCoordinator = new ManualVRFCoordinatorMock();
        rulesHarness = new BaccaratRulesHarness();

        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));
        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));

        GameDeploymentFactory.BaccaratDeployment memory params = GameDeploymentFactory.BaccaratDeployment({
            vrfCoordinator: address(autoVrfCoordinator),
            configHash: keccak256("super-baccarat-auto"),
            developerRewardBps: 500
        });
        address controllerAddress;
        address engineAddress;
        (, controllerAddress, engineAddress, ) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.SuperBaccarat), abi.encode(params));
        autoController = SuperBaccaratController(controllerAddress);
        autoEngine = SuperBaccaratEngine(engineAddress);

        delayedEngine = new SuperBaccaratEngine(address(catalog), address(manualVrfCoordinator));
        delayedController = new SuperBaccaratController(address(settlement), address(catalog), address(delayedEngine));
        delayedModuleId = catalog.registerModule(
            GameCatalog.Module({
                mode: GameCatalog.GameMode.Solo,
                controller: address(delayedController),
                engine: address(delayedEngine),
                engineType: delayedEngine.engineType(),
                verifier: address(0),
                configHash: keccak256("super-baccarat-manual"),
                developerRewardBps: 500,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        bytes32 engineType = autoEngine.engineType();
        vm.prank(developer);
        expressionTokenId = expressionRegistry.mintExpression(engineType, keccak256("super-baccarat"), "ipfs://super-baccarat");

        token.mint(player, 10_000 ether);
        vm.prank(player);
        token.approve(address(settlement), type(uint256).max);
    }

    function test_AutoFlowStartsAndSettlesImmediately() public {
        vm.prank(player);
        uint256 sessionId = autoController.play(
            100 ether, uint8(BaccaratTypes.BaccaratSide.Player), keccak256("auto"), expressionTokenId
        );

        (,,, bool fulfilled) = autoEngine.getSettlementOutcome(sessionId);
        assertTrue(fulfilled);

        autoController.settle(sessionId);
        assertTrue(autoController.sessionSettled(sessionId));
    }

    function test_DelayedFlowPaysNeutralMultipliersForAllSides() public {
        uint256 playerWinSeed = _findSeed(BaccaratTypes.BaccaratOutcome.PlayerWin);
        uint256 bankerWinSeed = _findSeed(BaccaratTypes.BaccaratOutcome.BankerWin);
        uint256 tieSeed = _findSeed(BaccaratTypes.BaccaratOutcome.Tie);

        vm.startPrank(player);
        uint256 playerSession =
            delayedController.play(100 ether, uint8(BaccaratTypes.BaccaratSide.Player), keccak256("player"), expressionTokenId);
        uint256 bankerSession =
            delayedController.play(100 ether, uint8(BaccaratTypes.BaccaratSide.Banker), keccak256("banker"), expressionTokenId);
        uint256 tieSession =
            delayedController.play(100 ether, uint8(BaccaratTypes.BaccaratSide.Tie), keccak256("tie"), expressionTokenId);
        uint256 pushSession =
            delayedController.play(100 ether, uint8(BaccaratTypes.BaccaratSide.Player), keccak256("push"), expressionTokenId);
        vm.stopPrank();

        manualVrfCoordinator.fulfillRequestWithWord(playerSession, playerWinSeed);
        manualVrfCoordinator.fulfillRequestWithWord(bankerSession, bankerWinSeed);
        manualVrfCoordinator.fulfillRequestWithWord(tieSession, tieSeed);
        manualVrfCoordinator.fulfillRequestWithWord(pushSession, tieSeed);

        delayedController.settle(playerSession);
        delayedController.settle(bankerSession);
        delayedController.settle(tieSession);
        delayedController.settle(pushSession);

        uint256 expectedBalance = 10_000 ether - (400 ether)
            + ((100 ether * delayedEngine.PLAYER_PAYOUT_WAD()) / 1e18)
            + ((100 ether * delayedEngine.BANKER_PAYOUT_WAD()) / 1e18)
            + ((100 ether * delayedEngine.TIE_PAYOUT_WAD()) / 1e18)
            + 100 ether;
        assertEq(token.balanceOf(player), expectedBalance);
        assertEq(developerRewards.epochAccrual(developerRewards.currentEpoch(), developer), 20 ether);
    }

    function test_RevertsForInvalidInputsAndPendingOrDuplicateSettlement() public {
        vm.prank(player);
        vm.expectRevert("SuperBaccarat: invalid wager");
        delayedController.play(0, uint8(BaccaratTypes.BaccaratSide.Player), keccak256("bad-wager"), expressionTokenId);

        vm.prank(player);
        vm.expectRevert("SuperBaccarat: invalid side");
        delayedController.play(1, 7, keccak256("bad-side"), expressionTokenId);

        vm.prank(player);
        uint256 sessionId =
            delayedController.play(100 ether, uint8(BaccaratTypes.BaccaratSide.Player), keccak256("pending"), expressionTokenId);

        vm.expectRevert("SuperBaccaratController: pending");
        delayedController.settle(sessionId);

        manualVrfCoordinator.fulfillRequestWithWord(sessionId, _findSeed(BaccaratTypes.BaccaratOutcome.PlayerWin));
        delayedController.settle(sessionId);

        vm.expectRevert("SuperBaccaratController: settled");
        delayedController.settle(sessionId);
    }

    function test_RetiredAndDisabledLifecycleGatesMatchSoloModules() public {
        catalog.setModuleStatus(delayedModuleId, GameCatalog.ModuleStatus.RETIRED);

        vm.prank(player);
        vm.expectRevert("SuperBaccaratController: module inactive");
        delayedController.play(100 ether, uint8(BaccaratTypes.BaccaratSide.Player), keccak256("retired"), expressionTokenId);

        catalog.setModuleStatus(delayedModuleId, GameCatalog.ModuleStatus.LIVE);
        vm.prank(player);
        uint256 sessionId =
            delayedController.play(100 ether, uint8(BaccaratTypes.BaccaratSide.Player), keccak256("disabled"), expressionTokenId);
        manualVrfCoordinator.fulfillRequestWithWord(sessionId, _findSeed(BaccaratTypes.BaccaratOutcome.PlayerWin));

        catalog.setModuleStatus(delayedModuleId, GameCatalog.ModuleStatus.DISABLED);
        vm.expectRevert("SuperBaccaratController: module inactive");
        delayedController.settle(sessionId);
    }

    function _findSeed(BaccaratTypes.BaccaratOutcome outcome) internal view returns (uint256 seed) {
        for (seed = 1; seed < 50_000; seed++) {
            (BaccaratTypes.BaccaratOutcome resolvedOutcome,,,,,) = rulesHarness.resolve(seed);
            if (resolvedOutcome == outcome) {
                return seed;
            }
        }
        revert("seed not found");
    }
}
