// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ScuroToken.sol";
import "../src/GameEngineRegistry.sol";
import "../src/CreatorRewards.sol";
import "../src/ProtocolSettlement.sol";
import "../src/engines/NumberPickerEngine.sol";
import "../src/controllers/NumberPickerAdapter.sol";
import "../src/mocks/VRFCoordinatorMock.sol";

contract NumberPickerAdapterTest is Test {
    ScuroToken internal token;
    GameEngineRegistry internal registry;
    CreatorRewards internal creatorRewards;
    ProtocolSettlement internal settlement;
    VRFCoordinatorMock internal vrfCoordinator;
    NumberPickerEngine internal engine;
    NumberPickerAdapter internal adapter;

    address internal alice = address(0xA11CE);
    address internal creator = address(0xC0FFEE);

    function setUp() public {
        token = new ScuroToken(address(this));
        registry = new GameEngineRegistry(address(this));
        creatorRewards = new CreatorRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(address(this), address(token), address(registry), address(creatorRewards));
        vrfCoordinator = new VRFCoordinatorMock();
        engine = new NumberPickerEngine(address(this), address(vrfCoordinator));
        adapter = new NumberPickerAdapter(address(this), address(settlement), address(registry), address(engine));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(creatorRewards));
        creatorRewards.grantRole(creatorRewards.SETTLEMENT_ROLE(), address(settlement));

        settlement.setControllerAuthorization(address(adapter), true);
        engine.grantRole(engine.ADAPTER_ROLE(), address(adapter));
        registry.registerEngine(
            address(engine),
            GameEngineRegistry.EngineMetadata({
                engineType: engine.ENGINE_TYPE(),
                creator: creator,
                verifier: address(0),
                configHash: bytes32(0),
                creatorRateBps: 500,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        token.mint(alice, 1_000 ether);
        vm.prank(alice);
        token.approve(address(settlement), type(uint256).max);
    }

    function test_PlayBurnsWagerFinalizesAndAccruesCreatorRewards() public {
        uint256 wager = 100 ether;
        vm.prank(alice);
        uint256 requestId = adapter.play(wager, 10, keccak256("play-1"));

        (, uint256 recordedWager, , , uint256 payout, , bool fulfilled) = engine.getOutcome(requestId);
        assertTrue(fulfilled);
        assertEq(recordedWager, wager);
        assertEq(token.balanceOf(alice), 1_000 ether - wager + payout);
        assertEq(creatorRewards.epochAccrual(creatorRewards.currentEpoch(), creator), 5 ether);
        assertTrue(adapter.requestSettled(requestId));
    }

    function test_CreatorRewardsMintOnlyAfterEpochClose() public {
        vm.prank(alice);
        adapter.play(100 ether, 25, keccak256("play-2"));

        vm.expectRevert("CreatorRewards: epoch open");
        uint256[] memory epochs = new uint256[](1);
        epochs[0] = 1;
        vm.prank(creator);
        creatorRewards.claim(epochs);

        vm.warp(block.timestamp + 7 days + 1);
        creatorRewards.closeCurrentEpoch();

        uint256 creatorBalanceBefore = token.balanceOf(creator);
        vm.prank(creator);
        creatorRewards.claim(epochs);
        assertEq(token.balanceOf(creator), creatorBalanceBefore + 5 ether);
    }
}
