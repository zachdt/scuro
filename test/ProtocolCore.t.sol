// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../src/DeveloperRewards.sol";
import {GameEngineRegistry} from "../src/GameEngineRegistry.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroGovernor} from "../src/ScuroGovernor.sol";
import {ScuroStakingToken} from "../src/ScuroStakingToken.sol";
import {ScuroToken} from "../src/ScuroToken.sol";

contract ProtocolCoreTest is Test {
    bytes32 internal constant NUMBER_PICKER_TYPE = keccak256("NUMBER_PICKER");
    bytes32 internal constant BLACKJACK_TYPE = keccak256("BLACKJACK");

    ScuroToken internal token;
    ScuroStakingToken internal stakingToken;
    TimelockController internal timelock;
    ScuroGovernor internal governor;
    GameEngineRegistry internal registry;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal controller = address(0xC0DE);
    address internal engine = address(0x1234);

    function setUp() public {
        token = new ScuroToken(address(this));
        stakingToken = new ScuroStakingToken(address(token));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(1, proposers, executors, address(this));
        governor = new ScuroGovernor(stakingToken, timelock, 1, 5, 1 ether);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

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

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));
        developerRewards.grantRole(developerRewards.EPOCH_MANAGER_ROLE(), address(timelock));

        token.mint(alice, 1_000 ether);
    }

    function test_StakingChangesVotingPower() public {
        vm.startPrank(alice);
        token.approve(address(stakingToken), 100 ether);
        stakingToken.stake(100 ether);
        stakingToken.delegate(alice);
        vm.stopPrank();

        assertEq(stakingToken.balanceOf(alice), 100 ether);
        assertEq(stakingToken.getVotes(alice), 100 ether);
    }

    function test_GovernanceCanUpdateDeveloperEpochDuration() public {
        vm.startPrank(alice);
        token.approve(address(stakingToken), 500 ether);
        stakingToken.stake(500 ether);
        stakingToken.delegate(alice);
        vm.stopPrank();
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = address(developerRewards);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(DeveloperRewards.setEpochDuration, (14 days));
        string memory description = "update epoch duration";

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + 2);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(developerRewards.epochDuration(), 14 days);
    }

    function test_UnauthorizedContractsCannotBurnMintOrAccrue() public {
        vm.startPrank(alice);
        token.approve(address(settlement), 10 ether);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert();
        settlement.burnPlayerWager(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert();
        settlement.mintPlayerReward(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert();
        settlement.accrueDeveloperForExpression(address(0x1234), 1, 1 ether);

        settlement.setControllerAuthorization(controller, true);
        vm.prank(controller);
        settlement.burnPlayerWager(alice, 1 ether);
        assertEq(token.balanceOf(alice), 999 ether);
    }

    function test_SettlementRoutesDeveloperAccrualToExpressionOwnerAndHonorsTransfers() public {
        registry.registerEngine(
            engine,
            GameEngineRegistry.EngineMetadata({
                engineType: NUMBER_PICKER_TYPE,
                verifier: address(0),
                configHash: keccak256("number-picker-auto"),
                developerRewardBps: 500,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        vm.prank(alice);
        uint256 expressionTokenId =
            expressionRegistry.mintExpression(NUMBER_PICKER_TYPE, keccak256("expr-1"), "ipfs://expr-1");

        settlement.setControllerAuthorization(controller, true);

        vm.prank(controller);
        settlement.accrueDeveloperForExpression(engine, expressionTokenId, 100 ether);
        assertEq(developerRewards.epochAccrual(1, alice), 5 ether);
        assertEq(developerRewards.epochAccrual(1, bob), 0);

        vm.prank(alice);
        expressionRegistry.transferFrom(alice, bob, expressionTokenId);

        vm.prank(controller);
        settlement.accrueDeveloperForExpression(engine, expressionTokenId, 200 ether);
        assertEq(developerRewards.epochAccrual(1, alice), 5 ether);
        assertEq(developerRewards.epochAccrual(1, bob), 10 ether);
    }

    function test_SettlementRejectsInactiveOrMismatchedExpressions() public {
        registry.registerEngine(
            engine,
            GameEngineRegistry.EngineMetadata({
                engineType: NUMBER_PICKER_TYPE,
                verifier: address(0),
                configHash: keccak256("number-picker-auto"),
                developerRewardBps: 500,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        vm.prank(alice);
        uint256 numberPickerExpressionId =
            expressionRegistry.mintExpression(NUMBER_PICKER_TYPE, keccak256("expr-1"), "ipfs://expr-1");
        vm.prank(alice);
        uint256 blackjackExpressionId =
            expressionRegistry.mintExpression(BLACKJACK_TYPE, keccak256("expr-2"), "ipfs://expr-2");

        settlement.setControllerAuthorization(controller, true);

        expressionRegistry.setExpressionActive(numberPickerExpressionId, false);
        vm.prank(controller);
        vm.expectRevert("Settlement: expression inactive");
        settlement.accrueDeveloperForExpression(engine, numberPickerExpressionId, 100 ether);

        vm.prank(controller);
        vm.expectRevert("Settlement: expression mismatch");
        settlement.accrueDeveloperForExpression(engine, blackjackExpressionId, 100 ether);
    }
}
