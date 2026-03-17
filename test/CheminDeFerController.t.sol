// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../src/DeveloperRewards.sol";
import {GameCatalog} from "../src/GameCatalog.sol";
import {GameDeploymentFactory} from "../src/GameDeploymentFactory.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroToken} from "../src/ScuroToken.sol";
import {CheminDeFerController} from "../src/controllers/CheminDeFerController.sol";
import {CheminDeFerEngine} from "../src/engines/CheminDeFerEngine.sol";
import {BaccaratTypes} from "../src/libraries/BaccaratTypes.sol";
import {ManualVRFCoordinatorMock} from "./e2e/helpers/ManualVRFCoordinatorMock.sol";
import {BaccaratRulesHarness} from "./helpers/BaccaratRulesHarness.sol";

contract CheminDeFerControllerTest is Test {
    ScuroToken internal token;
    GameCatalog internal catalog;
    GameDeploymentFactory internal factory;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    ManualVRFCoordinatorMock internal manualVrfCoordinator;
    BaccaratRulesHarness internal rulesHarness;

    CheminDeFerController internal controller;
    CheminDeFerEngine internal engine;
    uint256 internal moduleId;
    uint256 internal expressionTokenId;

    address internal developer = address(0xD00D);
    address internal banker = address(0xAAA1);
    address internal taker1 = address(0xAAA2);
    address internal taker2 = address(0xAAA3);
    address internal outsider = address(0xAAA4);

    function setUp() public {
        token = new ScuroToken(address(this));
        catalog = new GameCatalog(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(address(token), address(catalog), address(expressionRegistry), address(developerRewards));
        factory = new GameDeploymentFactory(address(this), address(catalog), address(settlement));
        manualVrfCoordinator = new ManualVRFCoordinatorMock();
        rulesHarness = new BaccaratRulesHarness();

        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));
        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));

        GameDeploymentFactory.CheminDeFerDeployment memory params = GameDeploymentFactory.CheminDeFerDeployment({
            vrfCoordinator: address(manualVrfCoordinator),
            joinWindow: 60,
            configHash: keccak256("chemin-de-fer"),
            developerRewardBps: 1_000
        });
        address controllerAddress;
        address engineAddress;
        (moduleId, controllerAddress, engineAddress, ) =
            factory.deployPvPModule(uint8(GameDeploymentFactory.MatchFamily.CheminDeFerBaccarat), abi.encode(params));
        controller = CheminDeFerController(controllerAddress);
        engine = CheminDeFerEngine(engineAddress);

        bytes32 engineType = engine.engineType();
        vm.prank(developer);
        expressionTokenId = expressionRegistry.mintExpression(engineType, keccak256("chemin-de-fer"), "ipfs://chemin-de-fer");

        _fundAndApprove(banker, 10_000);
        _fundAndApprove(taker1, 10_000);
        _fundAndApprove(taker2, 10_000);
        _fundAndApprove(outsider, 10_000);
    }

    function test_PlayerWinDistributesProRataAndRefundsUnmatchedBankerEscrow() public {
        vm.prank(banker);
        uint256 tableId = controller.openTable(1_000, keccak256("player-win"), expressionTokenId);

        vm.prank(taker1);
        controller.take(tableId, 200);
        vm.prank(taker2);
        controller.take(tableId, 400);

        vm.prank(banker);
        controller.closeTable(tableId);

        manualVrfCoordinator.fulfillRequestWithWord(1, _findSeed(BaccaratTypes.BaccaratOutcome.PlayerWin));
        controller.settle(tableId);

        assertEq(token.balanceOf(banker), 9_384);
        assertEq(token.balanceOf(taker1), 10_205);
        assertEq(token.balanceOf(taker2), 10_411);
        assertEq(developerRewards.epochAccrual(developerRewards.currentEpoch(), developer), 121);
    }

    function test_BankerWinPaysBankerMatchedPotAndTieRefundsEveryone() public {
        vm.prank(banker);
        uint256 bankerWinTable = controller.openTable(1_000, keccak256("banker-win"), expressionTokenId);

        vm.prank(taker1);
        controller.take(bankerWinTable, 500);
        vm.prank(banker);
        controller.closeTable(bankerWinTable);

        manualVrfCoordinator.fulfillRequestWithWord(1, _findSeed(BaccaratTypes.BaccaratOutcome.BankerWin));
        controller.settle(bankerWinTable);

        assertEq(token.balanceOf(banker), 10_500);
        assertEq(token.balanceOf(taker1), 9_500);

        vm.prank(banker);
        uint256 tieTable = controller.openTable(1_000, keccak256("tie"), expressionTokenId);
        vm.prank(taker1);
        controller.take(tieTable, 500);
        vm.prank(banker);
        controller.closeTable(tieTable);

        manualVrfCoordinator.fulfillRequestWithWord(2, _findSeed(BaccaratTypes.BaccaratOutcome.Tie));
        controller.settle(tieTable);

        assertEq(token.balanceOf(banker), 10_500);
        assertEq(token.balanceOf(taker1), 9_500);
        assertEq(developerRewards.epochAccrual(developerRewards.currentEpoch(), developer), 202);
    }

    function test_OverfillAutoCloseCancelAndDuplicateSettlementGuards() public {
        vm.prank(banker);
        uint256 tableId = controller.openTable(1_000, keccak256("auto-close"), expressionTokenId);

        uint256 cap = controller.playerTakeCap(1_000);

        vm.prank(taker1);
        vm.expectRevert("CheminDeFerController: take exceeds cap");
        controller.take(tableId, cap + 1);

        vm.prank(taker1);
        controller.take(tableId, cap);
        (,,,,,,,, bool closed,) = controller.tables(tableId);
        assertTrue(closed);

        manualVrfCoordinator.fulfillRequestWithWord(1, _findSeed(BaccaratTypes.BaccaratOutcome.BankerWin));
        controller.settle(tableId);

        vm.expectRevert("CheminDeFerController: settled");
        controller.settle(tableId);

        vm.prank(banker);
        uint256 cancelTableId = controller.openTable(750, keccak256("cancel"), expressionTokenId);
        vm.prank(banker);
        controller.cancelTable(cancelTableId);
        assertEq(token.balanceOf(banker), 10_000 + cap);
    }

    function test_ForceCloseAndLifecycleGuards() public {
        vm.prank(banker);
        uint256 tableId = controller.openTable(1_000, keccak256("force"), expressionTokenId);
        vm.prank(taker1);
        controller.take(tableId, 300);

        vm.expectRevert("CheminDeFerController: join active");
        controller.forceCloseTable(tableId);

        vm.warp(block.timestamp + 61);
        controller.forceCloseTable(tableId);

        catalog.setModuleStatus(moduleId, GameCatalog.ModuleStatus.DISABLED);
        vm.expectRevert("CheminDeFerController: module inactive");
        controller.settle(tableId);

        catalog.setModuleStatus(moduleId, GameCatalog.ModuleStatus.RETIRED);
        vm.prank(banker);
        vm.expectRevert("CheminDeFerController: module inactive");
        controller.openTable(100, keccak256("retired"), expressionTokenId);
    }

    function _fundAndApprove(address actor, uint256 amount) internal {
        token.mint(actor, amount);
        vm.prank(actor);
        token.approve(address(settlement), type(uint256).max);
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
