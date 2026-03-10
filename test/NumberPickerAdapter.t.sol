// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../src/DeveloperRewards.sol";
import {GameEngineRegistry} from "../src/GameEngineRegistry.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroToken} from "../src/ScuroToken.sol";
import {NumberPickerAdapter} from "../src/controllers/NumberPickerAdapter.sol";
import {NumberPickerEngine} from "../src/engines/NumberPickerEngine.sol";
import {VRFCoordinatorMock} from "../src/mocks/VRFCoordinatorMock.sol";

contract NumberPickerAdapterTest is Test {
    ScuroToken internal token;
    GameEngineRegistry internal registry;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    VRFCoordinatorMock internal vrfCoordinator;
    NumberPickerEngine internal engine;
    NumberPickerAdapter internal adapter;

    address internal alice = address(0xA11CE);
    address internal developer = address(0xC0FFEE);
    address internal collector = address(0xBEEF);
    uint256 internal expressionTokenId;

    function setUp() public {
        token = new ScuroToken(address(this));
        registry = new GameEngineRegistry(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(
            address(this),
            address(token),
            address(registry),
            address(expressionRegistry),
            address(developerRewards)
        );
        vrfCoordinator = new VRFCoordinatorMock();
        engine = new NumberPickerEngine(address(this), address(vrfCoordinator));
        adapter = new NumberPickerAdapter(address(this), address(settlement), address(registry), address(engine));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));

        settlement.setControllerAuthorization(address(adapter), true);
        engine.grantRole(engine.ADAPTER_ROLE(), address(adapter));
        registry.registerEngine(
            address(engine),
            GameEngineRegistry.EngineMetadata({
                engineType: engine.ENGINE_TYPE(),
                verifier: address(0),
                configHash: keccak256("number-picker-auto"),
                developerRewardBps: 500,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        bytes32 engineType = engine.ENGINE_TYPE();
        vm.prank(developer);
        expressionTokenId = expressionRegistry.mintExpression(
            engineType, keccak256("number-picker-auto"), "ipfs://scuro/number-picker-auto"
        );

        token.mint(alice, 1_000 ether);
        vm.prank(alice);
        token.approve(address(settlement), type(uint256).max);
    }

    function test_PlayBurnsWagerFinalizesAndAccruesDeveloperRewards() public {
        uint256 wager = 100 ether;
        vm.prank(alice);
        uint256 requestId = adapter.play(wager, 10, keccak256("play-1"), expressionTokenId);

        (, uint256 recordedWager, , , uint256 payout, , bool fulfilled) = engine.getOutcome(requestId);
        assertTrue(fulfilled);
        assertEq(recordedWager, wager);
        assertEq(token.balanceOf(alice), 1_000 ether - wager + payout);
        assertEq(developerRewards.epochAccrual(developerRewards.currentEpoch(), developer), 5 ether);
        assertEq(adapter.requestExpressionTokenId(requestId), expressionTokenId);
        assertTrue(adapter.requestSettled(requestId));
    }

    function test_TransferredExpressionOnlyRedirectsFutureAccruals() public {
        vm.prank(alice);
        adapter.play(100 ether, 25, keccak256("play-1"), expressionTokenId);

        vm.prank(developer);
        expressionRegistry.transferFrom(developer, collector, expressionTokenId);

        vm.prank(alice);
        adapter.play(200 ether, 25, keccak256("play-2"), expressionTokenId);

        assertEq(developerRewards.epochAccrual(1, developer), 5 ether);
        assertEq(developerRewards.epochAccrual(1, collector), 10 ether);
    }

    function test_DeveloperRewardsMintOnlyAfterEpochClose() public {
        vm.prank(alice);
        adapter.play(100 ether, 25, keccak256("play-2"), expressionTokenId);

        vm.expectRevert("DeveloperRewards: epoch open");
        uint256[] memory epochs = new uint256[](1);
        epochs[0] = 1;
        vm.prank(developer);
        developerRewards.claim(epochs);

        vm.warp(block.timestamp + 7 days + 1);
        developerRewards.closeCurrentEpoch();

        uint256 developerBalanceBefore = token.balanceOf(developer);
        vm.prank(developer);
        developerRewards.claim(epochs);
        assertEq(token.balanceOf(developer), developerBalanceBefore + 5 ether);
    }
}
